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

# [START hypercomputer_gpu_train_qwen2_slurm_preprocess_data]
import argparse
from datasets import load_dataset
from transformers import AutoTokenizer
import os
from itertools import chain

def get_args():
   parser = argparse.ArgumentParser(description="Download and preprocess a dataset.")
   parser.add_argument("--dataset_name", type=str, required=True)
   parser.add_argument("--dataset_config", type=str, required=True)
   parser.add_argument("--tokenizer_id", type=str, required=True)
   parser.add_argument("--max_seq_length", type=int, required=True)
   parser.add_argument("--output_path", type=str, required=True, help="Path to save the processed dataset.")
   return parser.parse_args()

def main():
   args = get_args()

   if os.path.exists(args.output_path) and os.listdir(args.output_path):
       print(f"Processed dataset already exists at {args.output_path}. Skipping.")
       return

   # 1. Load tokenizer
   tokenizer = AutoTokenizer.from_pretrained(args.tokenizer_id)

   # 2. Load raw dataset
   print(f"Loading raw dataset {args.dataset_name}...")
   raw_dataset = load_dataset(args.dataset_name, name=args.dataset_config, split="train")

   # 3. Tokenize
   def tokenize_function(examples):
       return tokenizer(examples["text"])

   num_proc = os.cpu_count()
   print(f"Tokenizing dataset using {num_proc} processes...")
   print("Tokenizing dataset...")
   tokenized_dataset = raw_dataset.map(
       tokenize_function,
       batched=True,
       remove_columns=raw_dataset.column_names,
       desc="Running tokenizer on dataset",
       num_proc=num_proc,
   )

   # 4. Group texts
   def group_texts(examples):
       concatenated_examples = {k: list(chain.from_iterable(examples[k])) for k in examples.keys()}
       total_length = len(concatenated_examples[list(examples.keys())[0]])
       if total_length >= args.max_seq_length:
           total_length = (total_length // args.max_seq_length) * args.max_seq_length
       result = {
           k: [t[i : i + args.max_seq_length] for i in range(0, total_length, args.max_seq_length)]
           for k, t in concatenated_examples.items()
       }
       result["labels"] = result["input_ids"].copy()
       return result

   print("Grouping texts...")
   lm_dataset = tokenized_dataset.map(
       group_texts,
       batched=True,
       desc=f"Grouping texts in chunks of {args.max_seq_length}",
       num_proc=num_proc,
   )

   # 5. Save to disk
   print(f"Saving processed dataset to {args.output_path}...")
   lm_dataset.save_to_disk(args.output_path)
   print("Preprocessing complete.")

if __name__ == "__main__":
   main()
# [END hypercomputer_gpu_train_qwen2_slurm_preprocess_data]
