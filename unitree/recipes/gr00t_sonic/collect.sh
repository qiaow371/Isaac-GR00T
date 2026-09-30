#!/usr/bin/env bash
# PICO + SONIC 采集。仿真: --sim ；真机: 默认（G1 相机 192.168.123.164）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"
require_wbc_script gear_sonic/scripts/launch_data_collection.py

MODE="real"
PROMPT="${PROMPT:-pick up the cookie box}"
EXTRA=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --sim) MODE=sim; shift ;;
        --real) MODE=real; shift ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        --) shift; EXTRA+=("$@"); break ;;
        *) EXTRA+=("$1"); shift ;;
    esac
done

cd "${WBC_DIR}"
mapfile -t SONIC_ARGS < <(sonic_ckpt_args || true)

CMD=(python3 gear_sonic/scripts/launch_data_collection.py)
    --task-prompt "${PROMPT}")
if [ "${MODE}" = "sim" ]; then
    CMD+=(--sim)
else
    CMD+=(--camera-host "${G1_CAMERA_HOST}")
fi
if [ "${#SONIC_ARGS[@]}" -gt 0 ]; then
    CMD+=("${SONIC_ARGS[@]}")
fi
if [ "${#EXTRA[@]}" -gt 0 ]; then
    CMD+=("${EXTRA[@]}")
fi

echo "[collect] mode=${MODE} variant=${SONIC_VARIANT} prompt=${PROMPT}"
echo "[collect] ${CMD[*]}"
echo "[collect] 真机：PICO Left Grip+A 开始；Grip+B 丢弃。VR_3PT 后处理必须 --no-remove-stale-smpl。"
exec "${CMD[@]}"
