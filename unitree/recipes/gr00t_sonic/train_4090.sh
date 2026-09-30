#!/usr/bin/env bash
# 4090 24GB：冻 VLM，bs=1 + gradient checkpointing。本仓没在 4090 跑通 N1.7，OOM 就停。
# 不要用本机 train.sh 的默认 bs=32。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GLOBAL_BATCH_SIZE="${GLOBAL_BATCH_SIZE:-1}"
export NUM_GPUS=1
export MAX_STEPS="${MAX_STEPS:-5000}"
export SAVE_STEPS="${SAVE_STEPS:-1000}"
export GR00T_USE_RELATIVE_ACTION="${GR00T_USE_RELATIVE_ACTION:-0}"
export DATALOADER_NUM_WORKERS="${DATALOADER_NUM_WORKERS:-2}"
# train.sh 吃掉第一个 --；finetune.sh 还要第二个 -- 才能把 tyro 参数交给 launch_finetune.py
exec bash "${SCRIPT_DIR}/train.sh" "$@" -- -- --gradient-checkpointing
