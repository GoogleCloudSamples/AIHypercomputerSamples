# [START hypercomputer_gpu_tune_gemma3_gke_dockerfile]
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
RUN apt-get update && \
    apt-get -y install python3 python3-dev gcc python3-pip python3-venv git curl vim
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:/usr/local/nvidia/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/nvidia/lib64:$LD_LIBRARY_PATH"
RUN pip3 install setuptools wheel packaging ninja
RUN pip3 install torch torchvision torchaudio  --index-url https://download.pytorch.org/whl/cu128

RUN pip3 install \
    transformers==4.53.3 \
    datasets==4.0.0 \
    accelerate==1.9.0 \
    evaluate==0.4.5 \
    bitsandbytes==0.46.1 \
    trl==0.19.1 \
    peft==0.16.0 \
    tensorboard==2.20.0 \
    protobuf==6.31.1 \
    sentencepiece==0.2.0
COPY finetune.py /finetune.py
COPY accel_fsdp_gemma3_config.yaml /accel_fsdp_gemma3_config.yaml
CMD accelerate launch --config_file accel_fsdp_gemma3_config.yaml finetune.py
# [END hypercomputer_gpu_tune_gemma3_gke_dockerfile]
