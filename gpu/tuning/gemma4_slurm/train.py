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

# [START hypercomputer_gpu_tune_gemma4_slurm_train]
import argparse

import torch
from datasets import load_dataset
from peft import LoraConfig
from transformers import AutoConfig, AutoModelForCausalLM, AutoTokenizer
from trl import SFTConfig, SFTTrainer


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_id", type=str, default="google/gemma-4-31B-it", help="Hugging Face model ID")
    parser.add_argument("--dataset_name", type=str, default="philschmid/gretel-synthetic-text-to-sql", help="Hugging Face dataset name")
    parser.add_argument("--output_dir", type=str, default="gemma4-text-to-sql", help="Directory to save model checkpoints")
    parser.add_argument("--seed", type=int, default=42, help="Seed for dataset sampling and training")

    # LoRA arguments
    parser.add_argument("--lora_r", type=int, default=16, help="LoRA attention dimension")
    parser.add_argument("--lora_alpha", type=int, default=32, help="LoRA alpha scaling factor")
    parser.add_argument("--lora_dropout", type=float, default=0.05, help="LoRA dropout probability")

    # SFTConfig arguments
    parser.add_argument("--max_length", type=int, default=1024, help="Maximum sequence length")
    parser.add_argument("--num_train_epochs", type=int, default=3, help="Number of training epochs")
    parser.add_argument("--per_device_train_batch_size", type=int, default=4, help="Batch size per device during training")
    parser.add_argument("--gradient_accumulation_steps", type=int, default=4, help="Gradient accumulation steps")
    parser.add_argument("--learning_rate", type=float, default=1e-5, help="Learning rate")
    parser.add_argument("--logging_steps", type=int, default=10, help="Log every X steps")
    parser.add_argument("--save_strategy", type=str, default="steps", help="Checkpoint save strategy")
    parser.add_argument("--save_steps", type=int, default=50, help="Save checkpoint every X steps")

    return parser.parse_args()


def main():
    args = get_args()

    # --- 1. Create and prepare the fine-tuning dataset ---
    dataset = load_dataset(args.dataset_name, split="train")
    dataset = dataset.shuffle(seed=args.seed).select(range(12500))
    dataset = dataset.train_test_split(test_size=2500 / 12500, seed=args.seed)

    # --- 2. Configure the tokenizer ---
    tokenizer = AutoTokenizer.from_pretrained(args.model_id)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    # --- 3. Define the formatting function ---
    # The SFTTrainer uses this function to format each sample from the
    # dataset with the tokenizer's chat template.
    def formatting_func(example):
        system_message = "You are a text to SQL query translator. Users will ask you questions in English and you will generate a SQL query based on the provided SCHEMA."
        user_prompt = "Given the <USER_QUERY> and the <SCHEMA>, generate the corresponding SQL command to retrieve the desired data, considering the query's syntax, semantics, and schema constraints.\n\n<SCHEMA>\n{context}\n</SCHEMA>\n\n<USER_QUERY>\n{question}\n</USER_QUERY>\n"

        messages = [
            {"role": "system", "content": system_message},
            {"role": "user", "content": user_prompt.format(question=example["sql_prompt"], context=example["sql_context"])},
            {"role": "assistant", "content": example["sql"]},
        ]
        return tokenizer.apply_chat_template(messages, tokenize=False)

    # --- 4. Load the model and configure LoRA ---
    config = AutoConfig.from_pretrained(args.model_id)
    config.use_cache = False

    # Load the base model in bfloat16
    print("Loading base model...")
    model = AutoModelForCausalLM.from_pretrained(
        args.model_id,
        config=config,
        attn_implementation="sdpa",
        dtype=torch.bfloat16,
    )

    # Configure LoRA.
    peft_config = LoraConfig(
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        r=args.lora_r,
        bias="none",
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
        exclude_modules=r".*(vision_tower|embed_vision|audio_tower|embed_audio).*",
        task_type="CAUSAL_LM",
    )

    # --- 5. Configure training arguments ---
    training_args = SFTConfig(
        output_dir=args.output_dir,
        seed=args.seed,
        max_length=args.max_length,
        num_train_epochs=args.num_train_epochs,
        per_device_train_batch_size=args.per_device_train_batch_size,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        learning_rate=args.learning_rate,
        logging_steps=args.logging_steps,
        save_strategy=args.save_strategy,
        save_steps=args.save_steps,
        packing=False,
        gradient_checkpointing=True,
        gradient_checkpointing_kwargs={"use_reentrant": False},
        optim="adamw_torch",
        bf16=True,
        max_grad_norm=0.3,
        warmup_steps=0.03,
        lr_scheduler_type="constant",
        push_to_hub=False,
        report_to="tensorboard",
    )

    # --- 6. Create the trainer and start training ---
    trainer = SFTTrainer(
        model=model,
        args=training_args,
        peft_config=peft_config,
        train_dataset=dataset["train"],
        eval_dataset=dataset["test"],
        processing_class=tokenizer,
        formatting_func=formatting_func,
    )
    trainer.model.print_trainable_parameters()

    print("Starting training...")
    trainer.train()
    print("Training finished.")

    # --- 7. Save the final LoRA adapter ---
    print(f"Saving final model to {args.output_dir}")
    if trainer.is_fsdp_enabled:
        trainer.accelerator.state.fsdp_plugin.set_state_dict_type("FULL_STATE_DICT")
    trainer.save_model(args.output_dir)
    if torch.distributed.is_initialized():
        torch.distributed.destroy_process_group()


if __name__ == "__main__":
    main()
# [END hypercomputer_gpu_tune_gemma4_slurm_train]
