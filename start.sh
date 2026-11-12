#!/usr/bin/env bash
# Startup script for the ComfyUI + H3 Editor RunPod template.
# Models and folders follow https://github.com/igorls/comfyui-h3-editor/blob/main/docs/models.md
set -euo pipefail

WS="${WORKSPACE:-/workspace}"
COMFY="$WS/ComfyUI"            # the whole ComfyUI install lives on the volume
MODELS="$COMFY/models"

# ---- Model switches (set as RunPod environment variables) -------------------
# HyperFlow H3 Flash: H3 Editor's default model
ENABLE_HYPERFLOW="${ENABLE_HYPERFLOW:-true}"
HYPERFLOW_FORMAT="${HYPERFLOW_FORMAT:-int8}"            # int8 (24 GB+ GPUs, 32 GB) | gguf (smaller GPUs)
HYPERFLOW_GGUF_QUANT="${HYPERFLOW_GGUF_QUANT:-Q4_K_M}"  # with gguf: Q8_0 | Q6_K | Q5_K_M | Q4_K_M | Q3_K_M ...
# Optional extras from the H3 Editor page
LATENT_UPSCALER="${LATENT_UPSCALER:-true}"              # finals up to 1920 px (0.7 GB)
REALISM_LORA="${REALISM_LORA:-true}"                    # MMH3-Realism-V2 LoRA from Civitai (71 MB)
LIVE_PREVIEW="${LIVE_PREVIEW:-true}"                    # taeh3 moving live preview (23 MB)
# Extra checkpoints for H3 Editor's Model menu (all off by default)
ENABLE_MINIMAX_H3="${ENABLE_MINIMAX_H3:-${ENABLE_H3_TURBO:-false}}"  # MiniMax H3 + H3 Turbo: 2 x 21 GB + Turbo LoRA
ENABLE_SINGULARITY="${ENABLE_SINGULARITY:-false}"       # Singularity v2 (Hugging Face, 21 GB)
ENABLE_10EROS="${ENABLE_10EROS:-false}"                 # 10Eros Max beta 7 (Hugging Face, 22.9 GB)
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"                      # only if Civitai asks for a login (Realism LoRA)

# ---- Other settings ---------------------------------------------------------
SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-false}"
UPDATE_COMFYUI="${UPDATE_COMFYUI:-false}"        # true = git pull ComfyUI, Manager and H3 Editor on boot
INSTALL_NODE_REQS="${INSTALL_NODE_REQS:-true}"   # reinstall custom nodes' Python packages on boot
COMFY_ARGS="${COMFY_ARGS:-}"                     # extra flags, e.g. --lowvram
ENABLE_JUPYTER="${ENABLE_JUPYTER:-true}"         # JupyterLab on port 8888
JUPYTER_PASSWORD="${JUPYTER_PASSWORD:-}"         # optional login token; empty = opens with no login
# -----------------------------------------------------------------------------

is_on() { [[ "${1,,}" == "true" || "$1" == "1" || "${1,,}" == "yes" ]]; }

# SSH (RunPod injects PUBLIC_KEY from your account settings)
if [[ -n "${PUBLIC_KEY:-}" ]]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
  ssh-keygen -A >/dev/null 2>&1 || true
  /usr/sbin/sshd || echo "[start] sshd failed to start (continuing)"
fi

mkdir -p "$WS"

# ---- ComfyUI on the volume --------------------------------------------------
# First boot: copy the ComfyUI install from the image to /workspace/ComfyUI, the
# usual layout (custom_nodes, models, input, output...). Later boots reuse it.
if [[ ! -f "$COMFY/main.py" ]]; then
  echo "[start] First boot: copying ComfyUI to $COMFY ..."
  mkdir -p "$COMFY"
  cp -an /opt/ComfyUI/. "$COMFY/"    # -n: never overwrite input/output/user already there
fi
# Custom nodes built into the image that the volume doesn't have yet (never
# overwrites a node folder that's already there).
for node in /opt/ComfyUI/custom_nodes/*/; do
  [[ -d "$node" ]] || continue
  name="$(basename "$node")"
  if [[ ! -e "$COMFY/custom_nodes/$name" ]]; then
    echo "[start] Adding custom node: $name"
    cp -a "$node" "$COMFY/custom_nodes/$name"
  fi
done

# JupyterLab — started before the model download so it's usable right away.
# Launched from $WS on purpose: Jupyter resolves a new terminal's folder against
# its OWN working directory first, so starting it anywhere else sent terminals
# to the wrong folder. --ip='*' listens on IPv4 and IPv6.
if [[ "$ENABLE_JUPYTER" == "true" ]]; then
  echo "[start] Starting JupyterLab on port 8888"
  (cd "$WS" && nohup jupyter lab --ip='*' --port=8888 --no-browser --allow-root \
    --IdentityProvider.token="$JUPYTER_PASSWORD" --ServerApp.password='' \
    --ServerApp.allow_origin='*' --ServerApp.allow_remote_access=True \
    --ServerApp.disable_check_xsrf=True --ServerApp.root_dir="$WS" \
    > /var/log/jupyter.log 2>&1 &)
fi

mkdir -p "$MODELS"/{diffusion_models/hyperflow,text_encoders,vae,vae_approx,loras,latent_upscale_models,checkpoints,upscale_models,embeddings,clip_vision} \
         "$COMFY/output" "$COMFY/input" "$COMFY/user" "$COMFY/custom_nodes"

# ---- Optional update + Python packages --------------------------------------
CONSTRAINTS=()
[[ -f /opt/torch-constraints.txt ]] && CONSTRAINTS=(-c /opt/torch-constraints.txt)   # keep the image's PyTorch
if [[ "$UPDATE_COMFYUI" == "true" ]]; then
  echo "[start] Updating ComfyUI, ComfyUI-Manager and H3 Editor ..."
  git -C "$COMFY" pull --ff-only || echo "[start] ComfyUI update failed (continuing)"
  for n in ComfyUI-Manager comfyui-h3-editor; do
    git -C "$COMFY/custom_nodes/$n" pull --ff-only 2>/dev/null || true
  done
fi
pip install -q -r "$COMFY/requirements.txt" "${CONSTRAINTS[@]}" || echo "[start] ComfyUI requirements install failed (continuing)"
if [[ "$INSTALL_NODE_REQS" == "true" ]]; then
  for req in "$COMFY"/custom_nodes/*/requirements.txt; do
    [[ -f "$req" ]] || continue
    echo "[start] Installing packages for custom node: $(basename "$(dirname "$req")")"
    pip install -q -r "$req" "${CONSTRAINTS[@]}" || echo "[start]   failed (continuing)"
  done
fi

# Bundled workflows → ComfyUI's Workflows panel (never overwrites your edits)
WF_DIR="$COMFY/user/default/workflows"
mkdir -p "$WF_DIR"
for wf in /opt/default_workflows/*.json; do
  [[ -e "$wf" ]] || continue
  if [[ ! -e "$WF_DIR/$(basename "$wf")" ]]; then
    cp "$wf" "$WF_DIR/" && echo "[start] Added workflow: $(basename "$wf")"
  fi
done

# Bundled LoRAs → models/loras (never overwrites a file that's already there)
for lora in /opt/default_loras/*.safetensors; do
  [[ -e "$lora" ]] || continue
  if [[ ! -e "$MODELS/loras/$(basename "$lora")" ]]; then
    cp "$lora" "$MODELS/loras/" && echo "[start] Added LoRA: $(basename "$lora")"
  fi
done

# ---- Build the file list ----------------------------------------------------
# Each entry is "huggingface-repo|file-name|folder under models/". The file is
# found by name anywhere in the repo (some sit in subfolders there).
FILES=(
  "Comfy-Org/MiniMax-H3|qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors|text_encoders"
  "Comfy-Org/MiniMax-H3|minimax_h3_video_vae_fp16.safetensors|vae"
  "Comfy-Org/MiniMax-H3|minimax_h3_audio_vae_fp32.safetensors|vae"
)
if is_on "$ENABLE_HYPERFLOW"; then
  HF_REPO="VideoRebirthAI/hyperflow-h3-flash"
  case "${HYPERFLOW_FORMAT,,}" in
    int8) FILES+=("$HF_REPO|minimax_h3_ref2va_hyperflow_flash_14b-int8_convrot.safetensors|diffusion_models/hyperflow"
                  "$HF_REPO|minimax_h3_fl2va_hyperflow_flash_14b-int8_convrot.safetensors|diffusion_models/hyperflow") ;;
    gguf) FILES+=("$HF_REPO|minimax_h3_ref2va_hyperflow_flash_14b-${HYPERFLOW_GGUF_QUANT}.gguf|diffusion_models/hyperflow"
                  "$HF_REPO|minimax_h3_fl2va_hyperflow_flash_14b-${HYPERFLOW_GGUF_QUANT}.gguf|diffusion_models/hyperflow") ;;
    *) echo "[start] Unknown HYPERFLOW_FORMAT=$HYPERFLOW_FORMAT (use int8 or gguf)"; exit 1 ;;
  esac
fi
if is_on "$ENABLE_MINIMAX_H3"; then
  FILES+=("Comfy-Org/MiniMax-H3|minimax_h3_ref2va_pruned_int8_convrot.safetensors|diffusion_models"
          "Comfy-Org/MiniMax-H3|minimax_h3_fl2va_pruned_int8_convrot.safetensors|diffusion_models"
          "larryvrh/MiniMax-H3-Turbo-Lora|minimax_h3_turbo_v4_step600_ema.safetensors|loras")
fi
is_on "$ENABLE_SINGULARITY" && FILES+=("WarmBloodAban/Minimax-h3_Singularity|Minimax-h3_Singularity_ref2va_v2_pruned_int8.safetensors|diffusion_models")
is_on "$ENABLE_10EROS"      && FILES+=("TenStrip/10Eros-Max|10Eros_Max_h3_8stepTURBO_beta7_fix1-native_int8_protected_edges_HQ.safetensors|diffusion_models")
is_on "$LATENT_UPSCALER" && FILES+=("LBH-123-AI/Minimax_h3_latent_Upscaler|minimax_h3_latent_upscaler_3d_conv_v1_bf16.safetensors|latent_upscale_models")
is_on "$LIVE_PREVIEW"    && FILES+=("OzzyGT/taeh3|taeh3.safetensors|vae_approx")
# Civitai downloads: "model-id|version regex|file regex|file exclude regex|save as|folder|already-there glob"
# The file is saved under the name H3 Editor looks for.
CIVITAI=()
is_on "$REALISM_LORA" && CIVITAI+=("3041489|v2|realism.*\.safetensors$|hyperflow|MMH3-Realism-V2.safetensors|loras|MMH3-Realism*.safetensors")

any_model=false
for v in ENABLE_HYPERFLOW ENABLE_MINIMAX_H3 ENABLE_SINGULARITY ENABLE_10EROS; do
  is_on "${!v}" && any_model=true
done
$any_model || echo "[start] !!! No checkpoint switched on — H3 Editor can't render. Set ENABLE_HYPERFLOW=true."

# ---- Download (skips files already on the volume) ---------------------------
wait_for_network() {
  for i in $(seq 1 60); do
    getent hosts huggingface.co >/dev/null 2>&1 && return 0
    echo "[start] Waiting for network ($i/60)..."
    sleep 2
  done
  return 1
}

target_of() { local e="$1"; local rest="${e#*|}"; echo "$MODELS/${rest#*|}/${rest%%|*}"; }

missing_files() {
  local e
  for e in "${FILES[@]}"; do [[ -s "$(target_of "$e")" ]] || echo "$e"; done
}

# Download one file by name from a repo, wherever it sits, then move it into place
fetch_hf() {
  local repo="$1" name="$2" dest="$3" stage found
  stage="$MODELS/.downloads/${repo//\//__}"
  mkdir -p "$stage" "$MODELS/$dest"
  echo "[start] Downloading $name from $repo ..."
  hf download "$repo" --include "$name" --include "*/$name" --local-dir "$stage" >/dev/null || return 1
  found="$(find "$stage" -type f -name "$name" -size +0 | head -1)"
  [[ -n "$found" ]] || { echo "[start]   $name not found in $repo"; return 1; }
  mv -f "$found" "$MODELS/$dest/$name"
}

# Civitai downloads via Civitai's public API: picks the version and file by name
civitai_present() {   # true when the file, or a file H3 Editor also accepts, is already there
  local dir="$MODELS/$1" save="$2" glob="$3"
  [[ -s "$dir/$save" ]] && return 0
  [[ -n "$glob" ]] && compgen -G "$dir/$glob" >/dev/null && return 0
  return 1
}
fetch_civitai() {
  local model="$1" vre="$2" fre="$3" xre="$4" save="$5" dir="$6"
  mkdir -p "$MODELS/$dir"
  echo "[start] Downloading $save from Civitai (model $model) ..."
  CIVITAI_TOKEN="$CIVITAI_TOKEN" python3 - "$model" "$vre" "$fre" "$xre" "$MODELS/$dir/$save" <<'PY'
import json, os, re, sys, urllib.request
model, vre, fre, xre, dest = sys.argv[1:6]
try:
  tok = os.environ.get("CIVITAI_TOKEN", "")
  hdr = {"User-Agent": "runpod-h3-template"}
  if tok: hdr["Authorization"] = "Bearer " + tok
  api = json.load(urllib.request.urlopen(urllib.request.Request(
      "https://civitai.com/api/v1/models/" + model, headers=hdr), timeout=60))
  picks = []
  for v in api.get("modelVersions", []):
    if not re.search(vre, v.get("name", ""), re.I):
      continue
    for f in v.get("files", []):
      n = f.get("name", "")
      if re.search(fre, n, re.I) and not (xre and re.search(xre, n, re.I)):
        picks.append((v["name"], f))
  if not picks:
    print("[start]   no matching file. Versions on Civitai:")
    for v in api.get("modelVersions", []):
      print("[start]     %s: %s" % (v.get("name"), ", ".join(f.get("name", "") for f in v.get("files", []))))
    sys.exit(1)
  vname, f = picks[0]
  print("[start]   %s -> %s" % (vname, f["name"]))
  with urllib.request.urlopen(urllib.request.Request(f["downloadUrl"], headers=hdr), timeout=600) as r, \
       open(dest + ".part", "wb") as out:
    while chunk := r.read(1 << 22):
      out.write(chunk)
  os.replace(dest + ".part", dest)
  print("[start]   saved as", os.path.basename(dest))
except SystemExit:
  raise
except Exception as e:
  print("[start]   Civitai download failed:", e); sys.exit(1)
PY
}

if [[ "$SKIP_DOWNLOAD" != "true" ]]; then
  export HF_HUB_DISABLE_TELEMETRY=1
  if ! wait_for_network; then
    echo "[start] !!! No network after 2 minutes — skipping model download."
  else
    for attempt in 1 2 3; do
      mapfile -t TODO < <(missing_files)
      (( ${#TODO[@]} == 0 )) && break
      echo "[start] ${#TODO[@]} model file(s) to download (attempt $attempt) ..."
      for e in "${TODO[@]}"; do
        IFS='|' read -r repo name dest <<< "$e"
        fetch_hf "$repo" "$name" "$dest" || echo "[start]   failed: $name"
      done
    done
    rm -rf "$MODELS/.downloads"
    for e in ${CIVITAI[@]+"${CIVITAI[@]}"}; do
      IFS='|' read -r model vre fre xre save dir glob <<< "$e"
      civitai_present "$dir" "$save" "$glob" && continue
      fetch_civitai "$model" "$vre" "$fre" "$xre" "$save" "$dir" || \
        echo "[start] !!! Couldn't download $save from Civitai (Civitai down, or set CIVITAI_TOKEN). Restart the pod to retry."
    done
  fi

  for e in ${CIVITAI[@]+"${CIVITAI[@]}"}; do
    IFS='|' read -r model vre fre xre save dir glob <<< "$e"
    civitai_present "$dir" "$save" "$glob" && echo "[start]   ✓ $dir/$save" || echo "[start] !!!   missing from Civitai: $dir/$save"
  done
  mapfile -t STILL_MISSING < <(missing_files)
  if (( ${#STILL_MISSING[@]} )); then
    echo "[start] !!! These model files are MISSING:"
    for e in "${STILL_MISSING[@]}"; do echo "[start] !!!   $(target_of "$e" | sed "s#$MODELS/##")"; done
    echo "[start] !!! ComfyUI will start anyway — restart the pod to retry the download."
  else
    echo "[start] All model files present:"
    for e in "${FILES[@]}"; do
      t="$(target_of "$e")"; echo "[start]   ✓ ${t#$MODELS/} ($(du -h "$t" | cut -f1))"
    done
  fi
fi

# ---- Launch ComfyUI ---------------------------------------------------------
cd "$COMFY"
echo "[start] Starting ComfyUI on port 8188 from $COMFY"
# --enable-cors-header: lets requests through RunPod's proxy (otherwise ComfyUI answers 403)
# shellcheck disable=SC2086
exec python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header $COMFY_ARGS
