#!/usr/bin/env bash
# SONIC 侧推理：PolicyServer(5550) + gear_sonic_deploy。仿真 --sim，真机默认。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"
require_wbc_script gear_sonic/scripts/launch_inference.py

MODE="real"
PROMPT="${PROMPT:-pick up the cookie box}"
SIM_SCENE=""
EXTRA=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --sim) MODE=sim; shift ;;
        --real) MODE=real; shift ;;
        --sim-scene) SIM_SCENE="$2"; shift 2 ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        --policy-host) POLICY_HOST="$2"; shift 2 ;;
        --policy-port) POLICY_PORT="$2"; shift 2 ;;
        --) shift; EXTRA+=("$@"); break ;;
        *) EXTRA+=("$1"); shift ;;
    esac
done

cd "${WBC_DIR}"
if [ -n "${SIM_SCENE}" ]; then
    case "${SIM_SCENE}" in
        pickplace|pickplace_toy)
            export SONIC_SIM_LOOP_EXTRA="${SONIC_SIM_LOOP_EXTRA:---wbc-version pickplace_toy}"
            bash "${SCRIPT_DIR}/install_sim_assets.sh"
            ;;
        empty|"")
            export SONIC_SIM_LOOP_EXTRA="${SONIC_SIM_LOOP_EXTRA:-}"
            ;;
        *)
            echo "[infer] 未知 --sim-scene ${SIM_SCENE}（pickplace|empty）" >&2
            exit 1
            ;;
    esac
fi
if [ -x .venv_inference/bin/activate ]; then
    # shellcheck disable=SC1091
    source .venv_inference/bin/activate
fi

mapfile -t SONIC_ARGS < <(sonic_ckpt_args || true)

CMD=(python3 gear_sonic/scripts/launch_inference.py
    --policy-host "${POLICY_HOST}"
    --policy-port "${POLICY_PORT}"
    --prompt "${PROMPT}")
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

echo "[infer] mode=${MODE} scene=${SIM_SCENE:-empty} policy=${POLICY_HOST}:${POLICY_PORT} variant=${SONIC_VARIANT}"
echo "[infer] 键盘: k 开环 → i 混到初始 pose → p 取消暂停"
echo "[infer] ${CMD[*]}"
exec "${CMD[@]}"
