#!/usr/bin/env bash
# 本机 SONIC 闭环自检。不启动训练、不杀进程。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

ok=0
bad=0
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*"; bad=$((bad + 1)); }
pass() { echo "[OK]   $*"; ok=$((ok + 1)); }

if [ -n "${GR00T_DIR}" ] && [ -d "${GR00T_DIR}" ]; then
    pass "Isaac-GR00T  ${GR00T_DIR}"
else
    fail "Isaac-GR00T 未找到"
fi

if [ -n "${GR00T_DIR}" ] && grep -q 'UNITREE_G1_SONIC' "${GR00T_DIR}/gr00t/data/embodiment_tags.py" 2>/dev/null; then
    pass "embodiment UNITREE_G1_SONIC 在源码里"
else
    fail "embodiment_tags.py 没有 UNITREE_G1_SONIC（不要用只有 TongBot NEW_EMBODIMENT 的旧树）"
fi

if PY="$(gr00t_python 2>/dev/null)"; then
    pass "GR00T python ${PY}"
    "${PY}" - <<'PY' || fail "torch/cuda 不可用"
import torch
print("      torch", torch.__version__, "cuda", torch.cuda.is_available(),
      torch.cuda.get_device_name(0) if torch.cuda.is_available() else "")
assert torch.cuda.is_available()
PY
else
    fail "Isaac-GR00T 没有 .conda/.venv python"
fi

if [ -n "${WBC_DIR}" ] && [ -d "${WBC_DIR}/gear_sonic" ]; then
    pass "WholeBodyControl  ${WBC_DIR}"
else
    fail "GR00T-WholeBodyControl 未 clone。bash recipes/gr00t_sonic/setup.sh"
fi

if [ -n "${WBC_DIR}" ]; then
    for s in \
        gear_sonic/scripts/launch_data_collection.py \
        gear_sonic/scripts/process_dataset.py \
        gear_sonic/scripts/launch_inference.py
    do
        if [ -f "${WBC_DIR}/${s}" ]; then
            pass "${s}"
        else
            fail "缺 ${s}"
        fi
    done
    if [ -d "${WBC_DIR}/gear_sonic_deploy" ]; then
        pass "gear_sonic_deploy 源码在"
    else
        warn "gear_sonic_deploy 目录没有（仿真/真机 C++ 编不过）"
    fi
fi

echo "[info] POLICY ${POLICY_HOST}:${POLICY_PORT}  tag=${EMBODIMENT_TAG}  variant=${SONIC_VARIANT}"
echo "[info] G1 camera ${G1_CAMERA_HOST}:${G1_CAMERA_PORT}（和 TongBot 192.168.1.x 不是一张网）"
if command -v ss >/dev/null 2>&1; then
    if ss -ltn | grep -q ":${POLICY_PORT} "; then
        warn "端口 ${POLICY_PORT} 已被占用"
    else
        pass "端口 ${POLICY_PORT} 空闲"
    fi
    if ss -ltn | grep -q ':5555 '; then
        warn "5555 有人（多半是 TongBot GR00T）。SONIC PolicyServer 用 5550。"
    fi
fi

echo
echo "OK=${ok} FAIL=${bad}"
if [ "${bad}" -gt 0 ]; then
    exit 1
fi
