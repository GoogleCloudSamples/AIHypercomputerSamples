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

# [START hypercomputer_gpu_tune_gemma3_ray_vision_train]
import argparse
import datetime
import ray
import ray.train.huggingface.transformers
import torch
from PIL import Image
from datasets import load_dataset
from peft import LoraConfig
from ray.train import ScalingConfig, RunConfig
from ray.train.torch import TorchTrainer
from transformers import AutoProcessor, AutoModelForImageTextToText, BitsAndBytesConfig
from trl import SFTConfig
from trl import SFTTrainer

# System message for the assistant
system_message = "You are an expert product description writer for Amazon."

# User prompt that combines the user query and the schema
user_prompt = """Create a Short Product description based on the provided <PRODUCT> and <CATEGORY> and image.
Only return description. The description should be SEO optimized and for a better mobile search experience.

<PRODUCT>
{product}
</PRODUCT>

<CATEGORY>
{category}
</CATEGORY>
"""

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_id", type=str, default="google/gemma-3-4b-it", help="Hugging Face model ID")
    # parser.add_argument("--hf_token", type=str, default=None, help="Hugging Face token for private models")
    parser.add_argument("--dataset_name", type=str, default="philschmid/amazon-product-descriptions-vlm", help="Hugging Face dataset name")
    parser.add_argument("--output_dir", type=str, default="gemma-3-4b-seo-optimized", help="Directory to save model checkpoints")
    parser.add_argument("--gcs_bucket", type=str, required=True, help="storage bucket name used to synchronize tasks and save checkpoints")
    parser.add_argument("--push_to_hub", help="Push model to Hugging Face hub", action="store_true")

    # LoRA arguments
    parser.add_argument("--lora_r", type=int, default=16, help="LoRA attention dimension")
    parser.add_argument("--lora_alpha", type=int, default=16, help="LoRA alpha scaling factor")
    parser.add_argument("--lora_dropout", type=float, default=0.05, help="LoRA dropout probability")

    # SFTConfig arguments
    parser.add_argument("--max_seq_length", type=int, default=512, help="Maximum sequence length")
    parser.add_argument("--num_train_epochs", type=int, default=3, help="Number of training epochs")
    parser.add_argument("--per_device_train_batch_size", type=int, default=1, help="Batch size per device during training")
    parser.add_argument("--gradient_accumulation_steps", type=int, default=4, help="Gradient accumulation steps")
    parser.add_argument("--learning_rate", type=float, default=2e-4, help="Learning rate")
    parser.add_argument("--logging_steps", type=int, default=10, help="Log every X steps")
    parser.add_argument("--save_strategy", type=str, default="epoch", help="Checkpoint save strategy")
    parser.add_argument("--save_steps", type=int, default=100, help="Save checkpoint every X steps")

    return parser.parse_args()

# Convert dataset to OAI messages
def format_data(sample):
    return {
        "messages": [
            {
                "role": "system",
                "content": [{"type": "text", "text": system_message}],
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": user_prompt.format(
                            product=sample["Product Name"],
                            category=sample["Category"],
                        ),
                    },
                    {
                        "type": "image",
                        "image": sample["image"],
                    },
                ],
            },
            {
                "role": "assistant",
                "content": [{"type": "text", "text": sample["description"]}],
            },
        ],
    }

def process_vision_info(messages: list[dict]) -> list[Image.Image]:
    image_inputs = []
    # Iterate through each conversation
    for msg in messages:
        # Get content (ensure it's a list)
        content = msg.get("content", [])
        if not isinstance(content, list):
            content = [content]

        # Check each content element for images
        for element in content:
            if isinstance(element, dict) and ("image" in element or element.get("type") == "image"):
                # Get the image and convert to RGB
                if "image" in element:
                    image = element["image"]
                else:
                    image = element
                image_inputs.append(image.convert("RGB"))
    return image_inputs

def train(args):
    # Load dataset from the hub
    dataset = load_dataset(args.dataset_name, split="train", streaming=True)

    # Convert dataset to OAI messages
    # need to use list comprehension to keep Pil.Image type, .mape convert image to bytes
    dataset = (format_data(sample) for sample in dataset)

    # Hugging Face model id
    model_id = args.model_id

    # Check if GPU benefits from bfloat16
    if torch.cuda.get_device_capability()[0] < 8:
        raise ValueError("GPU does not support bfloat16, please use a GPU that supports bfloat16.")

    # Define model init arguments
    model_kwargs = dict(
        attn_implementation="eager",  # Use "flash_attention_2" when running on Ampere or newer GPU
        torch_dtype=torch.bfloat16,  # What torch dtype to use, defaults to auto
        # device_map="auto",  # Let torch decide how to load the model
    )

    # BitsAndBytesConfig int-4 config
    model_kwargs["quantization_config"] = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_use_double_quant=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=model_kwargs["torch_dtype"],
        bnb_4bit_quant_storage=model_kwargs["torch_dtype"],
    )

    # Load model and tokenizer
    model = AutoModelForImageTextToText.from_pretrained(model_id, **model_kwargs)
    processor = AutoProcessor.from_pretrained(model_id, use_fast=True)

    peft_config = LoraConfig(
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        r=args.lora_r,
        bias="none",
        target_modules="all-linear",
        task_type="CAUSAL_LM",
        modules_to_save=[
            "lm_head",
            "embed_tokens",
        ],
    )

    args = SFTConfig(
        output_dir=args.output_dir,  # directory to save and repository id
        num_train_epochs=args.num_train_epochs,  # number of training epochs
        per_device_train_batch_size=args.per_device_train_batch_size,  # batch size per device during training
        gradient_accumulation_steps=args.gradient_accumulation_steps,  # number of steps before performing a backward/update pass
        gradient_checkpointing=True,  # use gradient checkpointing to save memory
        optim="adamw_torch_fused",  # use fused adamw optimizer
        logging_steps=args.logging_steps,  # log every N steps
        save_strategy=args.save_strategy,  # save checkpoint every epoch
        learning_rate=args.learning_rate,  # learning rate, based on QLoRA paper
        bf16=True,  # use bfloat16 precision
        max_grad_norm=0.3,  # max gradient norm based on QLoRA paper
        warmup_ratio=0.03,  # warmup ratio based on QLoRA paper
        lr_scheduler_type="constant",  # use constant learning rate scheduler
        push_to_hub=args.push_to_hub,  # push model to hub
        report_to="tensorboard",  # report metrics to tensorboard
        gradient_checkpointing_kwargs={
            "use_reentrant": False
        },  # use reentrant checkpointing
        dataset_text_field="",  # need a dummy field for collator
        dataset_kwargs={"skip_prepare_dataset": True},  # important for collator
    )
    args.remove_unused_columns = False  # important for collator

    # Create a data collator to encode text and image pairs
    def collate_fn(examples):
        texts = []
        images = []
        for example in examples:
            image_inputs = process_vision_info(example["messages"])
            text = processor.apply_chat_template(
                example["messages"], add_generation_prompt=False, tokenize=False
            )
            texts.append(text.strip())
            images.append(image_inputs)

        # Tokenize the texts and process the images
        batch = processor(text=texts, images=images, return_tensors="pt", padding=True)

        # The labels are the input_ids, and we mask the padding tokens and image tokens in the loss computation
        labels = batch["input_ids"].clone()

        # Mask image tokens
        boi_token = processor.tokenizer.special_tokens_map.get("boi_token")
        image_token_id = processor.tokenizer.convert_tokens_to_ids(boi_token) if boi_token else None

        # Mask tokens for not being used in the loss computation
        labels[labels == processor.tokenizer.pad_token_id] = -100
        if image_token_id is not None:
            labels[labels == image_token_id] = -100
        labels[labels == 262144] = -100

        batch["labels"] = labels
        return batch

    trainer = SFTTrainer(
        model=model,
        args=args,
        train_dataset=dataset,
        peft_config=peft_config,
        processing_class=processor,
        data_collator=collate_fn,
    )

    callback = ray.train.huggingface.transformers.RayTrainReportCallback()
    trainer.add_callback(callback)
    trainer = ray.train.huggingface.transformers.prepare_trainer(trainer)

    # Start training, the model will be automatically saved to the Hub and the output directory
    trainer.train()

    # Save the final model again to the Hugging Face Hub
    trainer.save_model()

if __name__ == "__main__":
    args = get_args()
    print("Starting training task!")
    training_name = f"gemma_vision_train_{datetime.datetime.now().strftime('%Y_%m_%d_%H_%M_%S')}"

    gcs_bucket = args.gcs_bucket
    if not gcs_bucket.startswith("gs://"):
        gcs_bucket = "gs://" + gcs_bucket

    run_config = RunConfig(
        storage_path=gcs_bucket,
        name=training_name,
    )
    scaling_config = ScalingConfig(num_workers=16, use_gpu=True, accelerator_type="B200")
    ray_trainer = TorchTrainer(train, train_loop_config=args, scaling_config=scaling_config, run_config=run_config)
    print("Commencing training!")
    result = ray_trainer.fit()

    # [END hypercomputer_gpu_tune_gemma3_ray_vision_train]
