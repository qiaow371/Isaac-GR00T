#!/bin/bash
# GR00T N1.7 全量微调 - 00073
# 与 finetune_00073_full 同配方，唯一差异：allow_padding=True
# （结尾凑不齐 16 步的起点保留，缺的未来动作重复最后一拍补满）
#
# 输出目录已标记 ALLOW PADDING:
#   /data/gr00t/outputs/finetune_00073_full_allow_padding
set -euo pipefail

GR00T_DIR="/home/cqcigai/Isaac-GR00T"
PYTHON="${GR00T_DIR}/.venv/bin/python"
DATASET="/data/datasets/00073_20260818_RM_01_yj_21"
MODALITY_CONFIG="${GR00T_DIR}/examples/00073_tong_dual_arm/00073_config.py"
# 文件夹名明确带 allow_padding，避免和 finetune_00073_full 混淆
OUTPUT_DIR="/data/gr00t/outputs/finetune_00073_full_allow_padding"
BASE_MODEL="/data/gr00t/outputs/finetune_00073_s2/checkpoint-100000"
PROMPT="Using both hands, pick up the courier items from the green conveyor belt. Place the white courier bags into the left box and the brown courier boxes into the right box."

export GR00T_BACKBONE_PATH="/data/gr00t/Isaac-GR00T/nvidia/Cosmos-Reason2-2B"
export CUDA_VISIBLE_DEVICES=0
export PYTHONUNBUFFERED=1
export TOKENIZERS_PARALLELISM=false
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_HUB_DISABLE_XET=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

TASK=$(python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["task"])' "${DATASET}/meta/tasks.jsonl")
if [ "$TASK" != "$PROMPT" ]; then
  echo "[ERROR] 00073 prompt mismatch:"
  echo "  expected: $PROMPT"
  echo "  got:      $TASK"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
printf 'allow_padding=true\nallow_padding_effect=repeat_last_action_to_fill_chunk\nstarted_at=%s\n' "$(date -Is)" > "${OUTPUT_DIR}/ALLOW_PADDING.txt"
cd "${GR00T_DIR}"

echo "============================================================"
echo "  GR00T N1.7 全量微调 - 00073 tong_dual_arm"
echo "  ALLOW PADDING = TRUE  (folder: finetune_00073_full_allow_padding)"
echo "============================================================"
echo "  time:          $(date)"
echo "  host:          $(hostname)"
echo "  model:         ${BASE_MODEL}"
echo "  backbone:      ${GR00T_BACKBONE_PATH}"
echo "  dataset:       ${DATASET}"
echo "  output:        ${OUTPUT_DIR}"
echo "  allow_padding: TRUE"
echo "  tune_llm:      true"
echo "  tune_visual:   true"
echo "  max_steps:     100000"
echo "  batch:         16 x accum 2 (effective 32)"
echo "  lr:            1e-4"
echo "============================================================"

exec "${PYTHON}" \
    gr00t/experiment/launch_finetune.py \
    --base-model-path "${BASE_MODEL}" \
    --dataset-path "${DATASET}" \
    --embodiment-tag NEW_EMBODIMENT \
    --modality-config-path "${MODALITY_CONFIG}" \
    --num-gpus 1 \
    --output-dir "${OUTPUT_DIR}" \
    --experiment-name finetune_00073_full_allow_padding \
    --max-steps 100000 \
    --global-batch-size 16 \
    --dataloader-num-workers 4 \
    --learning-rate 1e-4 \
    --save-steps 1000 \
    --save-total-limit 5 \
    --gradient-accumulation-steps 2 \
    --state-dropout-prob 0.2 \
    --allow-padding \
    --tune-llm \
    --tune-visual \
    --tune-projector \
    --tune-diffusion-model
