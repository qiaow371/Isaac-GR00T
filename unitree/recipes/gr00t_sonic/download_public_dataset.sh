#!/usr/bin/env bash
# 拉公开、且格式是 UNITREE_G1_SONIC 的 LeRobot 集。NVIDIA 没有放 18k 抓取 VLA。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

OUT="${SONIC_DATA_ROOT:-${HOME}/VLA/datasets}"
NAME="${1:-pickplace_toy}"
mkdir -p "${OUT}"

HF="${HF:-}"
if command -v hf >/dev/null 2>&1; then
    HF_BIN=hf
elif command -v huggingface-cli >/dev/null 2>&1; then
    HF_BIN=huggingface-cli
else
    echo "需要 huggingface-cli / hf" >&2
    exit 1
fi

case "${NAME}" in
    pickplace_toy)
        REPO="SII-ZhangYiFei/G1-WholeBody-PickPlaceToy"
        DEST="${OUT}/G1-WholeBody-PickPlaceToy"
        PROMPT='pick up the toy and place it on the chair'
        ;;
    bones_seed)
        REPO="wsagi/SONIC-VLA-BonesSeed"
        DEST="${OUT}/SONIC-VLA-BonesSeed"
        PROMPT='walk'
        ;;
    *)
        echo "用法: bash download_public_dataset.sh [pickplace_toy|bones_seed]" >&2
        echo "  pickplace_toy = 128 ep 玩具放椅子（可训可仿真放物体）" >&2
        echo "  bones_seed    = 7 ep 走/跳/舞（空场地，不够当操作策略）" >&2
        exit 1
        ;;
esac

echo "[download] ${REPO} -> ${DEST}"
export HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}"
if [ "${HF_BIN}" = "hf" ]; then
    if ! hf download "${REPO}" --repo-type dataset --local-dir "${DEST}"; then
        echo "[download] 官方 HF 不通，改走 hf-mirror.com"
        HF_ENDPOINT=https://hf-mirror.com hf download "${REPO}" --repo-type dataset --local-dir "${DEST}"
    fi
else
    huggingface-cli download --repo-type dataset "${REPO}" --local-dir "${DEST}"
fi

if [ ! -f "${DEST}/meta/modality.json" ]; then
    echo "[download] 缺 meta/modality.json，下载不完整" >&2
    exit 1
fi
python3 - <<PY
import json
from pathlib import Path
p=Path("${DEST}")/"meta"/"modality.json"
m=json.loads(p.read_text())
tok=m.get("action",{}).get("motion_token",{})
dim=int(tok.get("end",0))-int(tok.get("start",0))
print(f"[download] motion_token dim={dim} original_key={tok.get('original_key')}")
if dim!=64:
    raise SystemExit("not 64-d SONIC motion_token")
PY

echo "[download] 训练:"
echo "  bash ${SCRIPT_DIR}/train.sh --dataset-path ${DEST} --experiment-name g1_sonic_${NAME}"
echo "[download] 仿真部署物体:"
echo "  bash ${SCRIPT_DIR}/install_sim_assets.sh"
echo "  bash ${SCRIPT_DIR}/infer.sh --sim --sim-scene pickplace --prompt '${PROMPT}'"
