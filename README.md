# H3 Editor + ComfyUI (MiniMax H3 video)

Ready-to-use ComfyUI with **H3 Editor**, a video editor for MiniMax H3, plus JupyterLab. All models download by themselves on the first start. Nothing to install.

## Start here

1. Pick a GPU (see below) and set the **CUDA filter to 13.0+**.
2. Deploy. The first start downloads ~55 GB (10–30 min). Watch the **Logs** for `Starting ComfyUI on port 8188`.
3. Click **Connect → ComfyUI**. **H3 Editor** is in the left sidebar.

### Which GPU should I pick?

| GPU | Setting |
|---|---|
| **48 GB+** (L40S, A6000, A100, H100) | Nothing to change (recommended) |
| **24–32 GB** (RTX 4090, RTX 5090) | Set `HYPERFLOW_FORMAT` to `gguf` |

💡 Pick **64 GB+ system RAM** and a **Volume Disk of 100 GB**. Add ~25 GB for each extra model below.

To change a setting, click **Edit Template** when you deploy and change it in the **Environment Variables**.

---

## Models

Always downloaded (from Comfy-Org/MiniMax-H3):
- `qwen3vl_32b_minimax_h3_nvfp4_awq` text encoder (15.7 GB)
- `minimax_h3_video_vae_fp16` (5.2 GB) and `minimax_h3_audio_vae_fp32` (0.6 GB)

## Switches

| Variable | Default | What it does |
|---|---|---|
| `ENABLE_HYPERFLOW` | `true` | HyperFlow H3 Flash, H3 Editor's default model (2 files, 32 GB) |
| `HYPERFLOW_FORMAT` | `int8` | `int8` for 48 GB+, `gguf` for smaller GPUs |
| `HYPERFLOW_GGUF_QUANT` | `Q4_K_M` | With gguf: `Q8_0` (best, 30 GB) to `Q3_K_M` (smallest, 15 GB) |
| `LATENT_UPSCALER` | `true` | Finals up to 1920 px (0.7 GB) |
| `REALISM_LORA` | `true` | MMH3-Realism LoRA from Civitai, natural skin in finals |
| `LIVE_PREVIEW` | `true` | Moving live preview while rendering (23 MB) |
| `CIVITAI_TOKEN` | — | Only if Civitai asks for a login for the Realism LoRA |

## Extra models (all `false` by default)
Switch on the ones you want, all from Hugging Face. They appear in H3 Editor's **Model** menu.

| Variable | Model | Size |
|---|---|---|
| `ENABLE_MINIMAX_H3` | MiniMax H3 + MiniMax H3 Turbo | 42 GB |
| `ENABLE_SINGULARITY` | Singularity v2 | 21 GB |
| `ENABLE_10EROS` | 10Eros Max beta 7 | 23 GB |

**Other:** `UPDATE_COMFYUI=true` updates ComfyUI and Manager on start. `JUPYTER_PASSWORD` sets a Jupyter login. `COMFY_ARGS` adds ComfyUI flags. `HF_TOKEN` is a Hugging Face token.

## What's included
- ComfyUI + ComfyUI-Manager + **H3 Editor 0.4.1**, PyTorch for CUDA 13.0
- JupyterLab (no password), port 8888
- Everything in `/workspace/ComfyUI` (`custom_nodes`, `models`, `output`…). Custom nodes persist.

## Ports
`8188` ComfyUI · `8888` JupyterLab · `22` SSH

## Licenses
HyperFlow H3 Flash and MiniMax H3 are under the **MiniMax H3 Community License**: check it before commercial use. LoRAs and other files have their own licenses.

Links: [H3 Editor](https://github.com/igorls/comfyui-h3-editor) · [HyperFlow H3 Flash](https://huggingface.co/VideoRebirthAI/hyperflow-h3-flash) · [MiniMax H3](https://huggingface.co/Comfy-Org/MiniMax-H3)
