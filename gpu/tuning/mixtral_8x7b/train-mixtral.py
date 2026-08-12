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

# [START hypercomputer_gpu_tune_mixtral_slurm_train_py]
import torch
from torch.distributed.fsdp import MixedPrecision
from datasets import load_dataset
import shutil
import os
import torch.distributed as dist

from peft import LoraConfig, PeftModel, get_peft_model
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    HfArgumentParser,
)

from torch.distributed import get_rank, get_world_size

from transformers.models.mixtral.modeling_mixtral import MixtralDecoderLayer
from trl import SFTTrainer
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class ScriptArguments:
    model_id: str = field(default="mistralai/Mixtral-8x7B-v0.1", metadata={"help": "Hugging Face model ID from the Hub"})
    dataset_name: str = field(default="philschmid/gretel-synthetic-text-to-sql", metadata={"help": "Dataset from the Hub"})
    run_inference_after_training: bool = field(default=False, metadata={"help": "Run sample inference on rank 0 after training"})
    dataset_subset_size: Optional[int] = field(default=None, metadata={"help": "Number of samples to use from the dataset for training. If None, uses the full dataset."})

@dataclass
class PeftArguments:
    lora_r: int = field(default=16, metadata={"help": "LoRA attention dimension"})
    lora_alpha: int = field(default=32, metadata={"help": "LoRA alpha scaling factor"})
    lora_dropout: float = field(default=0.05, metadata={"help": "LoRA dropout probability"})

@dataclass
class SftTrainingArguments(TrainingArguments):
    max_length: Optional[int] = field(default=2048, metadata={"help": "The maximum sequence length for SFTTrainer"})
    packing: Optional[bool] = field(default=False, metadata={"help": "Enable packing for SFTTrainer"})
    ddp_find_unused_parameters: Optional[bool] = field(default=False, metadata={"help": "When using FSDP activation checkpointing, this must be set to False for Mixtral"})

def formatting_prompts_func(example):
    system_message = "You are a text to SQL query translator. Users will ask you questions in English and you will generate a SQL query based on the provided SCHEMA."
    user_prompt = f"### SCHEMA:\n{example['sql_context']}\n\n### USER QUERY:\n{example['sql_prompt']}"
    response = f"\n\n### SQL QUERY:\n{example['sql']}"
    return f"{system_message}\n\n{user_prompt}{response}"

def main():
    parser = HfArgumentParser((ScriptArguments, PeftArguments, SftTrainingArguments))
    script_args, peft_args, training_args = parser.parse_args_into_dataclasses()

    training_args.gradient_checkpointing = True
    training_args.gradient_checkpointing_kwargs = {"use_reentrant": True}

    training_args.optim = "adamw_torch_fused"

    bf16_policy = MixedPrecision(
        param_dtype=torch.bfloat16,
        reduce_dtype=torch.bfloat16,
        buffer_dtype=torch.bfloat16,
    )

    training_args.fsdp = "full_shard"
    training_args.fsdp_config = {
        "fsdp_auto_wrap_policy": "TRANSFORMER_BASED_WRAP",
        "fsdp_transformer_layer_cls_to_wrap": [MixtralDecoderLayer],
        "fsdp_state_dict_type": "SHARDED_STATE_DICT",
        "fsdp_offload_params": False,
        "fsdp_forward_prefetch": True,
        "fsdp_mixed_precision_policy": bf16_policy
    }

    tokenizer = AutoTokenizer.from_pretrained(script_args.model_id, trust_remote_code=True)

    tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"

    model = AutoModelForCausalLM.from_pretrained(
        script_args.model_id,
        torch_dtype=torch.bfloat16,
        trust_remote_code=True,
        attn_implementation="flash_attention_2",
    )

    peft_config = LoraConfig(
        r=peft_args.lora_r,
        lora_alpha=peft_args.lora_alpha,
        lora_dropout=peft_args.lora_dropout,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=["q_proj", "v_proj", "k_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    )

    model = get_peft_model(model, peft_config)

    data_splits = load_dataset(script_args.dataset_name)

    dataset = data_splits["train"]
    eval_dataset = data_splits["test"]

    if script_args.dataset_subset_size is not None:
        dataset = dataset.select(range(script_args.dataset_subset_size))

    dataset = dataset.shuffle(seed=training_args.seed)

    trainer = SFTTrainer(
        model=model,
        args=training_args,
        train_dataset=dataset,
        eval_dataset=eval_dataset,
        formatting_func=formatting_prompts_func,
        processing_class=tokenizer,
    )

    trainer.train()

    dist.barrier()
    if trainer.is_world_process_zero():
        best_model_path = trainer.state.best_model_checkpoint

        final_model_dir = os.path.join(training_args.output_dir, "final_best_model")
        print(f"Copying best model to: {final_model_dir}")

        if os.path.exists(final_model_dir):
            shutil.rmtree(final_model_dir)
        shutil.copytree(best_model_path, final_model_dir)

        if script_args.run_inference_after_training:
            del model, trainer
            torch.cuda.empty_cache()
            run_post_training_inference(script_args, final_model_dir, tokenizer)

def run_post_training_inference(script_args, best_model_path, tokenizer):
    print("\n" + "="*50)
    print("=== RUNNING POST-TRAINING INFERENCE TEST ===")
    print("="*50 + "\n")

    base_model = AutoModelForCausalLM.from_pretrained(
        script_args.model_id,
        torch_dtype=torch.bfloat16,
        trust_remote_code=True,
        device_map="auto"
    )
    model = PeftModel.from_pretrained(base_model, best_model_path)
    model = model.merge_and_unload()
    model.eval()

    # Define the test case
    schema = "CREATE TABLE artists (Name TEXT, Country TEXT, Genre TEXT)"
    system_message = "You are a text to SQL query translator. Users will ask you questions in English and you will generate a SQL query based on the provided SCHEMA."
    question = "Show me all artists from the Country just north of the USA."

    prompt = f"{system_message}\n\n### SCHEMA:\n{schema}\n\n### USER QUERY:\n{question}\n\n### SQL QUERY:\n"

    print(f"Test Prompt:\n{prompt}")

    inputs = tokenizer(prompt, return_tensors="pt").to("cuda")

    print("\n--- Generating SQL... ---")
    outputs = model.generate(
        **inputs,
        max_new_tokens=100,
        pad_token_id=tokenizer.eos_token_id,
        do_sample=False,
        temperature=None,
        top_p=None,
    )

    generated_sql = tokenizer.decode(outputs[0], skip_special_tokens=True)[len(prompt):].strip()

    print(f"\n--- Generated SQL Query ---")
    print(generated_sql)
    print("\n" + "="*50)
    print("=== INFERENCE TEST COMPLETE ===")
    print("="*50 + "\n")

if __name__ == "__main__":
    main()
# [END hypercomputer_gpu_tune_mixtral_slurm_train_py]