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

# [START hypercomputer_gpu_tune_gemma4_ray_validate_adapter]
import argparse
import json
import os
import sys

import pyarrow.fs
import torch
from datasets import load_dataset
from peft import PeftModel
from safetensors import safe_open
from transformers import AutoModelForImageTextToText, AutoProcessor

from vision_train import format_data, process_vision_info


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_id", type=str, required=True, help="Hugging Face ID of the base model")
    parser.add_argument("--adapter_uri", type=str, required=True, help="gs:// URI of the checkpoint directory that holds adapter_model.safetensors")
    parser.add_argument("--dataset_name", type=str, default="philschmid/amazon-product-descriptions-vlm", help="Hugging Face dataset name")
    parser.add_argument("--local_dir", type=str, default="/tmp/gemma4-adapter", help="Local directory for the downloaded adapter")
    parser.add_argument("--max_new_tokens", type=int, default=128, help="Maximum number of generated tokens")
    return parser.parse_args()


def check_adapter(adapter_dir):
    with open(os.path.join(adapter_dir, "adapter_config.json")) as f:
        adapter_config = json.load(f)
    print("Adapter base model:", adapter_config.get("base_model_name_or_path"))

    with safe_open(os.path.join(adapter_dir, "adapter_model.safetensors"), framework="pt") as f:
        keys = list(f.keys())
    lora_keys = [k for k in keys if "lora_" in k]
    language_model_keys = [k for k in lora_keys if "language_model" in k]
    tower_keys = [k for k in lora_keys if "vision_tower" in k or "audio_tower" in k]
    print(f"Adapter tensors: total={len(keys)} lora={len(lora_keys)} "
          f"language_model={len(language_model_keys)} vision_or_audio_tower={len(tower_keys)}")
    if not language_model_keys:
        sys.exit("Validation failed: the adapter has no LoRA weights for the language model.")
    if tower_keys:
        sys.exit("Validation failed: the adapter has LoRA weights on the vision or audio tower.")


def main():
    args = get_args()

    print(f"1/4 Downloading the adapter from {args.adapter_uri}...")
    os.makedirs(args.local_dir, exist_ok=True)
    pyarrow.fs.copy_files(args.adapter_uri.rstrip("/"), args.local_dir)

    print("2/4 Checking the adapter weights...")
    check_adapter(args.local_dir)

    print("3/4 Loading the base model and the fine-tuned adapter...")
    processor = AutoProcessor.from_pretrained(args.model_id)
    model = AutoModelForImageTextToText.from_pretrained(
        args.model_id,
        dtype=torch.bfloat16,
        attn_implementation={"": "sdpa", "text_config": "sdpa", "vision_config": "sdpa", "audio_config": "eager"},
        device_map="cuda",
    )
    model = PeftModel.from_pretrained(model, args.local_dir)
    model.eval()

    print("4/4 Generating a product description for a dataset sample...")
    sample = load_dataset(args.dataset_name, split="train[:1]")[0]
    messages = format_data(sample)["messages"][:-1]
    text = processor.apply_chat_template(messages, add_generation_prompt=True, tokenize=False)
    inputs = processor(
        text=[text],
        images=[process_vision_info(messages)],
        return_tensors="pt",
        padding=True,
    ).to(model.device)

    stop_token_ids = [
        processor.tokenizer.eos_token_id,
        processor.tokenizer.convert_tokens_to_ids("<turn|>"),
    ]
    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_new_tokens=args.max_new_tokens,
            do_sample=False,
            eos_token_id=stop_token_ids,
            disable_compile=True,
        )
    prompt_length = inputs["input_ids"].shape[1]
    description = processor.decode(output[0][prompt_length:], skip_special_tokens=True).strip()

    print("Product:", sample["Product Name"])
    print("Model output:", description)
    if not description:
        sys.exit("Validation failed: the fine-tuned model returned an empty description.")
    print("VALIDATION PASSED: the fine-tuned adapter loads and generates a description.")


if __name__ == "__main__":
    main()
# [END hypercomputer_gpu_tune_gemma4_ray_validate_adapter]
