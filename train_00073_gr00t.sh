#!/bin/bash
# GR00T N1.7 finetune - 00073 tong_dual_arm (gpu-node1)
set -euo pipefail

GR00T_DIR="/home/cqcigai/Isaac-GR00T"
PYTHON="${GR00T_DIR}/.venv/bin/python"
DATASET="/data/datasets/00073_20260818_RM_01_yj_21"
MODALITY_CONFIG="${GR00T_DIR}/examples/00073_tong_dual_arm/00073_config.py"
OUTPUT_DIR="/data/gr00t/outputs/finetune_00073"
BASE_MODEL="${GR00T_DIR}/checkpoints/GR00T-N1.7-3B"
PROMPT="Using both hands, pick up the courier items from the green conveyor belt. Place the white courier bags into the left box and the brown courier boxes into the right box."

export GR00T_BACKBONE_PATH="/data/gr00t/Isaac-GR00T/nvidia/Cosmos-Reason2-2B"
export CUDA_VISIBLE_DEVICES=0
export PYTHONUNBUFFERED=1
export TOKENIZERS_PARALLELISM=false
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_HUB_DISABLE_XET=1

# 开训前再确认数据集 prompt，防止串成 00036 香蕉柠檬 / 00072 药品
TASK=$(python3 -c "import json; print(json.loads(open('${DATASET}/meta/tasks.jsonl').readline())['task'])")
if [ "$TASK" != "$PROMPT" ]; then
  echo "[ERROR] 00073 prompt mismatch:"
  echo "  expected: $PROMPT"
  echo "  got:      $TASK"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
cd "${GR00T_DIR}"

echo "============================================================"
echo "  GR00T N1.7 微调 - 00073 tong_dual_arm"
echo "============================================================"
echo "  time:       $(date)"
echo "  host:       $(hostname)"
echo "  model:      ${BASE_MODEL}"
echo "  backbone:   ${GR00T_BACKBONE_PATH}"
echo "  dataset:    ${DATASET}"
echo "  modality:   ${MODALITY_CONFIG}"
echo "  output:     ${OUTPUT_DIR}"
echo "  Prompt:     ${PROMPT}"
echo "============================================================"

exec "${PYTHON}" \
    gr00t/experiment/launch_finetune.py \
    --base-model-path "${BASE_MODEL}" \
    --dataset-path "${DATASET}" \
    --embodiment-tag NEW_EMBODIMENT \
    --modality-config-path "${MODALITY_CONFIG}" \
    --num-gpus 1 \
    --output-dir "${OUTPUT_DIR}" \
    --max-steps 10000 \
    --global-batch-size 32 \
    --dataloader-num-workers 4 \
    --learning-rate 1e-4 \
    --save-steps 1000 \
    --save-total-limit 5 \
    --gradient-accumulation-steps 1 \
    --state-dropout-prob 0.2
