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

# [START hypercomputer_gpu_train_qwen2_slurm_train]
import torch
import argparse
from datasets import load_dataset, load_from_disk
import os
from transformers import (
    AutoConfig,
    AutoTokenizer,
    AutoModelForCausalLM,
    Trainer,
    TrainingArguments,
    DataCollatorForLanguageModeling,
)
from huggingface_hub import login

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_config_id", type=str, default="Qwen/Qwen2-1.5B", help="Hugging Face model config to use for architecture.")
    # Data arguments - used if preprocessed data is not available
    parser.add_argument("--dataset_name", type=str, default="HuggingFaceFW/fineweb-edu", help="Hugging Face dataset for pre-training.")
    parser.add_argument("--dataset_config", type=str, default="CC-MAIN-2024-10", help="Config for the fineweb-edu dataset, e.g., 'CC-MAIN-2024-10'.")
    parser.add_argument("--preprocessed_data_path", type=str, default=None, help="Path to a preprocessed dataset on disk. If provided, skips download and processing.")
    # General arguments
    parser.add_argument("--hf_token", type=str, default=None, help="Hugging Face token for private models/tokenizers")
    parser.add_argument("--output_dir", type=str, default="qwen2-from-scratch-on-smollm-fineweb", help="Directory to save model checkpoints")

    # TrainingArguments
    parser.add_argument("--max_seq_length", type=int, default=1024, help="Maximum sequence length")
    parser.add_argument("--num_train_epochs", type=int, default=1, help="Number of training epochs")
    parser.add_argument("--max_steps", type=int, default=-1, help="If set to a positive number, it overrides num_train_epochs.")
    parser.add_argument("--per_device_train_batch_size", type=int, default=4, help="Batch size per device during training")
    parser.add_argument("--gradient_accumulation_steps", type=int, default=4, help="Gradient accumulation steps")
    parser.add_argument("--learning_rate", type=float, default=5e-5, help="Learning rate")
    parser.add_argument("--logging_steps", type=int, default=10, help="Log every X steps")
    parser.add_argument("--save_strategy", type=str, default="steps", help="Checkpoint save strategy")
    parser.add_argument("--save_steps", type=int, default=500, help="Save checkpoint every X steps")

    return parser.parse_args()

def main():
    args = get_args()

    # --- 1. Setup and Login ---
    if args.hf_token:
        login(args.hf_token)

    # --- 2. Load Tokenizer ---
    # We load the tokenizer from the specified config ID to ensure compatibility
    # with the model architecture (e.g., special tokens).
    tokenizer = AutoTokenizer.from_pretrained(args.model_config_id)

    # --- 3. Initialize Model from Scratch ---
    print(f"Initializing a new model from {args.model_config_id} configuration...")
    config = AutoConfig.from_pretrained(args.model_config_id)
    model = AutoModelForCausalLM.from_config(config)

    print(f"Model has {model.num_parameters():,} parameters.")

    # --- 3. Load or Create and prepare the training dataset ---
    if args.preprocessed_data_path and os.path.exists(args.preprocessed_data_path):
        print(f"Loading preprocessed dataset from {args.preprocessed_data_path}...")

        # Synchronization of distributed processes
        if torch.distributed.is_initialized():
            local_rank = int(os.environ.get("LOCAL_RANK", 0))
            # Introducing a minimal time offset per GPU to avoid I/O collisions.
            import time
            time.sleep(local_rank * 0.2)

            lm_dataset = load_from_disk(args.preprocessed_data_path, keep_in_memory=False)

            torch.distributed.barrier()
        else:
            lm_dataset = load_from_disk(args.preprocessed_data_path, keep_in_memory=False)

    else:
        print("No preprocessed dataset found, starting from raw data...")
        raw_dataset = load_dataset(args.dataset_name, name=args.dataset_config, split="train")

        # Tokenization function
        def tokenize_function(examples):
            return tokenizer(examples["text"])

        tokenized_dataset = raw_dataset.map(
            tokenize_function,
            batched=True,
            remove_columns=raw_dataset.column_names,
            desc="Running tokenizer on dataset",
        )

        # Main data processing function that will concatenate all texts from our dataset
        # and generate chunks of max_seq_length.
        def group_texts(examples):
            # Concatenate all texts.
            concatenated_examples = {k: [item for sublist in examples[k] for item in sublist] for k in examples.keys()}
            total_length = len(concatenated_examples[list(examples.keys())[0]])
            # We drop the small remainder.
            if total_length >= args.max_seq_length:
                total_length = (total_length // args.max_seq_length) * args.max_seq_length
            # Split by chunks of max_len.
            result = {
                k: [t[i : i + args.max_seq_length] for i in range(0, total_length, args.max_seq_length)]
                for k, t in concatenated_examples.items()
            }
            result["labels"] = result["input_ids"].copy()
            return result

        lm_dataset = tokenized_dataset.map(
            group_texts,
            batched=True,
            desc=f"Grouping texts in chunks of {args.max_seq_length}",
        )

        # Tokenization function
        def tokenize_function(examples):
            return tokenizer(examples["text"])

        tokenized_dataset = raw_dataset.map(
            tokenize_function,
            batched=True,
            remove_columns=raw_dataset.column_names,
            desc="Running tokenizer on dataset",
        )

        # Main data processing function that will concatenate all texts from our dataset
        # and generate chunks of max_seq_length.
        def group_texts(examples):
            # Concatenate all texts.
            concatenated_examples = {k: [item for sublist in examples[k] for item in sublist] for k in examples.keys()}
            total_length = len(concatenated_examples[list(examples.keys())[0]])
            # We drop the small remainder.
            if total_length >= args.max_seq_length:
                total_length = (total_length // args.max_seq_length) * args.max_seq_length
            # Split by chunks of max_len.
            result = {
                k: [t[i : i + args.max_seq_length] for i in range(0, total_length, args.max_seq_length)]
                for k, t in concatenated_examples.items()
            }
            result["labels"] = result["input_ids"].copy()
            return result

        lm_dataset = tokenized_dataset.map(
            group_texts,
            batched=True,
            desc=f"Grouping texts in chunks of {args.max_seq_length}",
        )

    # --- 5. Configure Training Arguments ---
    # Check for bfloat16 support
    use_bf16 = torch.cuda.is_available() and torch.cuda.is_bf16_supported()

    training_args = TrainingArguments(
        output_dir=args.output_dir,
        num_train_epochs=args.num_train_epochs,
        max_steps=args.max_steps,
        per_device_train_batch_size=args.per_device_train_batch_size,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        learning_rate=args.learning_rate,
        logging_steps=args.logging_steps,
        save_strategy=args.save_strategy,
        save_steps=args.save_steps,
        save_total_limit=2, # Optional: Limit the number of checkpoints
        bf16=use_bf16,
        fp16=not use_bf16,
        optim="adamw_torch",
        lr_scheduler_type="cosine",
        warmup_ratio=0.03,
        report_to="tensorboard",
        gradient_checkpointing=True,
        # Required for gradient checkpointing with some parallelization strategies
        gradient_checkpointing_kwargs={"use_reentrant": False},
    )

    # --- 6. Create Trainer and Start Training ---
    # Data collator will take care of creating batches for causal language modeling
    data_collator = DataCollatorForLanguageModeling(tokenizer=tokenizer, mlm=False)

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=lm_dataset,
        # eval_dataset=... # Optional: if you have a validation set
        tokenizer=tokenizer,
        data_collator=data_collator,
    )

    print("Starting training from scratch...")
    trainer.train()
    print("Training finished.")

    # --- 7. Save the final model ---
    print(f"Saving final model to {args.output_dir}")
    trainer.save_model()

if __name__ == "__main__":
    main()
# [END hypercomputer_gpu_train_qwen2_slurm_train]
