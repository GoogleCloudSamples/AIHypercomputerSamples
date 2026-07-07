#  Copyright 2026 Google LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# [START hypercomputer_gpu_tune_gemma3_slurm_train]
import torch
import argparse
from datasets import load_dataset
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig, AutoConfig
from peft import LoraConfig, prepare_model_for_kbit_training, get_peft_model
from trl import SFTTrainer, SFTConfig
from huggingface_hub import login


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_id", type=str, default="google/gemma-3-12b-pt", help="Hugging Face model ID")
    parser.add_argument("--hf_token", type=str, default=None, help="Hugging Face token for private models")
    parser.add_argument("--dataset_name", type=str, default="philschmid/gretel-synthetic-text-to-sql", help="Hugging Face dataset name")
    parser.add_argument("--output_dir", type=str, default="gemma-12b-text-to-sql", help="Directory to save model checkpoints")

    # LoRA arguments
    parser.add_argument("--lora_r", type=int, default=16, help="LoRA attention dimension")
    parser.add_argument("--lora_alpha", type=int, default=16, help="LoRA alpha scaling factor")
    parser.add_argument("--lora_dropout", type=float, default=0.05, help="LoRA dropout probability")

    # SFTConfig arguments
    parser.add_argument("--max_seq_length", type=int, default=512, help="Maximum sequence length")
    parser.add_argument("--num_train_epochs", type=int, default=3, help="Number of training epochs")
    parser.add_argument("--per_device_train_batch_size", type=int, default=8, help="Batch size per device during training")
    parser.add_argument("--gradient_accumulation_steps", type=int, default=1, help="Gradient accumulation steps")
    parser.add_argument("--learning_rate", type=float, default=1e-5, help="Learning rate")
    parser.add_argument("--logging_steps", type=int, default=10, help="Log every X steps")
    parser.add_argument("--save_strategy", type=str, default="steps", help="Checkpoint save strategy")
    parser.add_argument("--save_steps", type=int, default=100, help="Save checkpoint every X steps")

    return parser.parse_args()

def main():
    args = get_args()

    # --- 1. Setup and Login ---
    if args.hf_token:
        login(args.hf_token)

    # --- 2. Create and prepare the fine-tuning dataset ---
    # The SFTTrainer will use the `formatting_func` to apply the chat template.
    dataset = load_dataset(args.dataset_name, split="train")
    dataset = dataset.shuffle().select(range(12500))
    dataset = dataset.train_test_split(test_size=2500/12500)

    # --- 3. Configure Model and Tokenizer ---
    if torch.cuda.is_available() and torch.cuda.get_device_capability()[0] >= 8:
        torch_dtype_obj = torch.bfloat16
        torch_dtype_str = "bfloat16"
    else:
        torch_dtype_obj = torch.float16
        torch_dtype_str = "float16"

    tokenizer = AutoTokenizer.from_pretrained(args.model_id)
    tokenizer.pad_token = tokenizer.eos_token

    gemma_chat_template = (
        "{% for message in messages %}"
        "{% if message['role'] == 'user' %}"
        "{{ '<start_of_turn>user\n' + message['content'] + '<end_of_turn>\n' }}"
        "{% elif message['role'] == 'assistant' %}"
        "{{ '<start_of_turn>model\n' + message['content'] + '<end_of_turn>\n' }}"
        "{% endif %}"
        "{% endfor %}"
        "{% if add_generation_prompt %}"
        "{{ '<start_of_turn>model\n' }}"
        "{% endif %}"
    )
    tokenizer.chat_template = gemma_chat_template

    # --- 4. Define the Formatting Function ---
    # This function will be used by the SFTTrainer to format each sample
    # from the dataset into the correct chat template format.
    def formatting_func(example):
        # The create_conversation logic is now implicitly handled by this.
        # We need to construct the messages list here.
        system_message = "You are a text to SQL query translator. Users will ask you questions in English and you will generate a SQL query based on the provided SCHEMA."
        user_prompt = "Given the <USER_QUERY> and the <SCHEMA>, generate the corresponding SQL command to retrieve the desired data, considering the query's syntax, semantics, and schema constraints.\n\n<SCHEMA>\n{context}\n</SCHEMA>\n\n<USER_QUERY>\n{question}\n</USER_QUERY>\n"

        messages = [
            {"role": "system", "content": system_message},
            {"role": "user", "content": user_prompt.format(question=example["sql_prompt"], context=example["sql_context"])},
            {"role": "assistant", "content": example["sql"]}
        ]
        return tokenizer.apply_chat_template(messages, tokenize=False)

    # --- 5. Load Quantized Model and Apply PEFT ---

    # Define the quantization configuration
    config = AutoConfig.from_pretrained(args.model_id)
    config.use_cache = False

    # Load the base model in native precision
    print("Loading base model...")
    model = AutoModelForCausalLM.from_pretrained(
        args.model_id,
        config=config,
        attn_implementation="sdpa",
        torch_dtype=torch_dtype_obj,
    )

    # Configure LoRA.
    peft_config = LoraConfig(
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        r=args.lora_r,
        bias="none",
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
        task_type="CAUSAL_LM",
    )

    # Apply the PEFT config to the model
    print("Applying PEFT configuration...")
    model = get_peft_model(model, peft_config)
    model.print_trainable_parameters()

    # --- 6. Configure Training Arguments ---
    training_args = SFTConfig(
        output_dir=args.output_dir,
        max_seq_length=args.max_seq_length,
        num_train_epochs=args.num_train_epochs,
        per_device_train_batch_size=args.per_device_train_batch_size,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        learning_rate=args.learning_rate,
        logging_steps=args.logging_steps,
        save_strategy=args.save_strategy,
        save_steps=args.save_steps,
        packing=True,
        gradient_checkpointing=True,
        gradient_checkpointing_kwargs={"use_reentrant": False},
        optim="adamw_torch",
        fp16=True if torch_dtype_obj == torch.float16 else False,
        bf16=True if torch_dtype_obj == torch.bfloat16 else False,
        max_grad_norm=0.3,
        warmup_ratio=0.03,
        lr_scheduler_type="constant",
        push_to_hub=False,
        report_to="tensorboard",
        dataset_kwargs={
            "add_special_tokens": False,
            "append_concat_token": True,
        }
    )

    # --- 7. Create Trainer and Start Training ---
    trainer = SFTTrainer(
        model=model,
        args=training_args,
        train_dataset=dataset["train"],
        eval_dataset=dataset["test"],
        formatting_func=formatting_func,
    )

    print("Starting training...")
    trainer.train()
    print("Training finished.")

    # --- 8. Save the final model ---
    print(f"Saving final model to {args.output_dir}")
    trainer.save_model()

if __name__ == "__main__":
    main()
# [END hypercomputer_gpu_tune_gemma3_slurm_train]
