# ComfyUI + H3 Editor (MiniMax H3 / HyperFlow H3 Flash) — RunPod pod template
# On first boot start.sh copies ComfyUI to /workspace/ComfyUI and downloads the models there.
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    SHELL=/bin/bash \
    PATH=/opt/venv/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-venv python3-dev build-essential \
        git wget curl ca-certificates ffmpeg libgl1 libglib2.0-0 \
        openssh-server tini \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd

RUN python3 -m venv /opt/venv && pip install --upgrade pip wheel setuptools

# PyTorch for CUDA 13.0 — current ComfyUI needs cu130 for its optimized CUDA ops.
# The wheels bundle their own CUDA runtime; the host only needs an NVIDIA driver >= 580.
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130

# ComfyUI — H3 Editor needs a recent build with built-in MiniMax H3 support, so track master by default.
# Pin with: docker build --build-arg COMFYUI_REF=<tag-or-commit> .
ARG COMFYUI_REF=master
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI && git checkout ${COMFYUI_REF} \
    && pip install -r requirements.txt

# ComfyUI-Manager (install extra nodes from the UI)
RUN git clone https://github.com/Comfy-Org/ComfyUI-Manager.git /opt/ComfyUI/custom_nodes/ComfyUI-Manager \
    && pip install -r /opt/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

# H3 Editor custom node (https://github.com/igorls/comfyui-h3-editor).
# Its requirements bring imageio-ffmpeg (video import/export) and gguf (HyperFlow GGUF files).
# The constraint keeps the PyTorch installed above, so no node can swap it out.
RUN pip freeze | grep -iE "^(torch|torchvision|torchaudio)==" > /opt/torch-constraints.txt \
    && git clone https://github.com/igorls/comfyui-h3-editor.git /opt/ComfyUI/custom_nodes/comfyui-h3-editor \
    && pip install -r /opt/ComfyUI/custom_nodes/comfyui-h3-editor/requirements.txt -c /opt/torch-constraints.txt

# Hugging Face CLI with Xet support (Xet-backed repos = fast downloads)
RUN pip install "huggingface_hub[hf_xet]"

# JupyterLab (port 8888) for file browsing, terminals and notebooks
RUN pip install jupyterlab

# Workflows bundled with the image (put .json files in the repo's workflows/ folder)
COPY workflows/ /opt/default_workflows/
COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /opt/ComfyUI
EXPOSE 8188 8888 22
ENTRYPOINT ["/usr/bin/tini", "-s", "--"]
CMD ["/start.sh"]
