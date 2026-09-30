#!/usr/bin/env bash
# 本机微调 GR00T N1.7，焊死 UNITREE_G1_SONIC（绝对 64+7+7，不要改成 UNITREE_G1 / 相对关节）。
# 单卡 RTX PRO 6000：NUM_GPUS=1 GLOBAL_BATCH_SIZE=32。官方教程是 4 卡 batch 32。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"
require_gr00t

DATASET_PATH="${DATASET_PATH:-}"
OUTPUT_DIR="${OUTPUT_DIR:-${HOME}/VLA/gr00t_sonic_outputs}"
EXPERIMENT_NAME="${EXPERIMENT_NAME:-g1_sonic_cookiebox}"
BASE_MODEL_PATH="${BASE_MODEL_PATH:-}"
if [ -z "${BASE_MODEL_PATH}" ]; then
    if [ -d "${HOME}/VLA/Isaac-GR00T/checkpoints/GR00T-N1.7-3B" ]; then
        BASE_MODEL_PATH="${HOME}/VLA/Isaac-GR00T/checkpoints/GR00T-N1.7-3B"
    else
        BASE_MODEL_PATH="nvidia/GR00T-N1.7-3B"
    fi
fi
# SONIC 动作是绝对 token，不要相对。
export GR00T_USE_RELATIVE_ACTION="${GR00T_USE_RELATIVE_ACTION:-0}"
if [ -d "${HOME}/VLA/Isaac-GR00T/checkpoints/Cosmos-Reason2-2B" ]; then
    export GR00T_BACKBONE_PATH="${GR00T_BACKBONE_PATH:-${HOME}/VLA/Isaac-GR00T/checkpoints/Cosmos-Reason2-2B}"
fi
NUM_GPUS="${NUM_GPUS:-1}"
MAX_STEPS="${MAX_STEPS:-20000}"
SAVE_STEPS="${SAVE_STEPS:-5000}"
GLOBAL_BATCH_SIZE="${GLOBAL_BATCH_SIZE:-32}"
USE_WANDB="${USE_WANDB:-0}"
EXTRA=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dataset-path) DATASET_PATH="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --experiment-name) EXPERIMENT_NAME="$2"; shift 2 ;;
        --base-model-path) BASE_MODEL_PATH="$2"; shift 2 ;;
        --num-gpus) NUM_GPUS="$2"; shift 2 ;;
        --max-steps) MAX_STEPS="$2"; shift 2 ;;
        --save-steps) SAVE_STEPS="$2"; shift 2 ;;
        --global-batch-size) GLOBAL_BATCH_SIZE="$2"; shift 2 ;;
        --use-wandb) USE_WANDB=1; shift ;;
        --) shift; EXTRA+=("$@"); break ;;
        *) EXTRA+=("$1"); shift ;;
    esac
done

if [ -z "${DATASET_PATH}" ] || [ ! -d "${DATASET_PATH}" ]; then
    echo "用法: bash train.sh --dataset-path /path/to/cleaned_lerobot_v21" >&2
    echo "  数据必须是 SONIC 导出：action.motion_token 64 + 双手 7+7。不要喂 TongBot 16D。" >&2
    exit 1
fi

if [ ! -f "${DATASET_PATH}/meta/modality.json" ]; then
    echo "[train] ${DATASET_PATH} 不像 LeRobot（缺 meta/modality.json）" >&2
    exit 1
fi

PY="$(gr00t_python)" || {
    echo "[train] 找不到 Isaac-GR00T python（.conda 或 .venv）" >&2
    exit 1
}

export NUM_GPUS SAVE_STEPS MAX_STEPS USE_WANDB GLOBAL_BATCH_SIZE
MODALITY="${GR00T_DIR}/gr00t/configs/data/embodiment_configs.py"

echo "[train] embodiment=${EMBODIMENT_TAG} gpus=${NUM_GPUS} bs=${GLOBAL_BATCH_SIZE} steps=${MAX_STEPS}"
echo "[train] dataset=${DATASET_PATH}"
echo "[train] out=${OUTPUT_DIR}/${EXPERIMENT_NAME}"
cd "${GR00T_DIR}"
exec env PATH="$(dirname "${PY}"):${PATH}" \
    bash examples/finetune.sh \
    --base-model-path "${BASE_MODEL_PATH}" \
    --dataset-path "${DATASET_PATH}" \
    --embodiment-tag "${EMBODIMENT_TAG}" \
    --modality-config-path "${MODALITY}" \
    --output-dir "${OUTPUT_DIR}" \
    --experiment-name "${EXPERIMENT_NAME}" \
    "${EXTRA[@]}"
