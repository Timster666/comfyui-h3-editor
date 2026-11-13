# MiniMax H3 Editor

Ready-to-use ComfyUI with **[H3 Editor 0.6.1](https://github.com/igorls/comfyui-h3-editor/releases/tag/v0.6.1)**, a video editor for MiniMax H3, plus JupyterLab. Everything downloads by itself on the first start. Nothing to install.

👉 What H3 Editor can do: [igorls.github.io/comfyui-h3-editor](https://igorls.github.io/comfyui-h3-editor/)

## Included by default

**Models, all ready in H3 Editor's Model menu:**

| Model | Size |
|---|---|
| **HyperFlow H3 Flash** (default, fastest) | 32 GB |
| **MiniMax H3** and **MiniMax H3 Turbo** | 42 GB |
| **Singularity v2** | 21 GB |
| **10Eros Max beta 7** | 23 GB |

**All recommended LoRAs:** the **MMH3 Realism V2** LoRA (natural skin in finals) and the **MiniMax H3 Turbo** LoRA.

**Also included:** the text encoder, video and audio VAEs, the latent upscaler (finals up to 1920 px) and the live preview.

**Plus:** ComfyUI + ComfyUI-Manager, JupyterLab (no password) and PyTorch for CUDA 13.0.

## Start here

1. Pick a GPU with **48 GB+ VRAM** (L40S, A6000, A100, H100, RTX PRO 6000) and **64 GB+ system RAM**.
2. Set the **CUDA filter to 13.0+** and the **Volume Disk to 200 GB**.
3. Deploy. The first start downloads ~141 GB of models (10–20 min). Watch the **Logs** for `Starting ComfyUI on port 8188`.
4. Click **Connect → ComfyUI**. **H3 Editor** is in the left sidebar.

Later starts are much faster, because the models are already there.

## Save space or money

Every model has an on/off switch. Click **Edit Template** when you deploy and set the ones you don't need to `false` in the **Environment Variables**:

| Switch | Model | Saves |
|---|---|---|
| `ENABLE_MINIMAX_H3` | MiniMax H3 + Turbo | 42 GB |
| `ENABLE_SINGULARITY` | Singularity v2 | 21 GB |
| `ENABLE_10EROS` | 10Eros Max beta 7 | 23 GB |

With all three off, a **100 GB** volume is enough.

**Smaller GPU (24–32 GB, e.g. RTX 4090 / 5090)?** Switch the three off and set `HYPERFLOW_FORMAT=gguf`. That uses a smaller HyperFlow file.

## Other settings
| Variable | Default | What it does |
|---|---|---|
| `HYPERFLOW_GGUF_QUANT` | `Q4_K_M` | With gguf: `Q8_0` (best) to `Q3_K_M` (smallest) |
| `UPDATE_COMFYUI` | `false` | `true` = update ComfyUI on start |
| `JUPYTER_PASSWORD` | — | Set to require a Jupyter login |

## Where things are saved
Everything is in `/workspace/ComfyUI`: `models`, `custom_nodes`, `output` (your videos) and more. Custom nodes you install stay between restarts.

## Ports
`8188` ComfyUI · `8888` JupyterLab · `22` SSH

## Licenses
MiniMax H3 and the models built on it use the **MiniMax H3 Community License**: check it before commercial use. LoRAs have their own licenses.
