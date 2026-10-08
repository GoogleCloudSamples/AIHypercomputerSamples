# [START hypercomputer_gpu_tune_gemma4_multihost_gke_dockerfile]
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
RUN apt-get update && \
    apt-get -y install python3 python3-dev gcc python3-pip \
        python3-venv git curl vim && \
    rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:/usr/local/nvidia/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/nvidia/lib64:$LD_LIBRARY_PATH"
RUN pip3 install setuptools wheel packaging ninja
RUN pip3 install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128
RUN pip3 install \
    "transformers>=5.5.0" \
    trl==0.29.1 \
    peft==0.18.1 \
    accelerate==1.13.0 \
    bitsandbytes==0.49.2 \
    datasets==4.8.4 \
    evaluate==0.4.5 \
    tensorboard==2.20.0 \
    protobuf==6.31.1 \
    sentencepiece==0.2.0
WORKDIR /workspace
COPY finetune.py /workspace/finetune.py
COPY accel_fsdp_gemma4_config.yaml /workspace/accel_fsdp_gemma4_config.yaml
CMD ["accelerate", "launch", "--config_file", "/workspace/accel_fsdp_gemma4_config.yaml", "/workspace/finetune.py"]
# [END hypercomputer_gpu_tune_gemma4_multihost_gke_dockerfile]
