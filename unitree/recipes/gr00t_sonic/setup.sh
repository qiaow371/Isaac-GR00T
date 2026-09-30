#!/usr/bin/env bash
# 本机准备 G1 SONIC 闭环：clone WholeBodyControl（不进 data_Driven）。
# 官方 venv / TensorRT / PICO APK 要用 --install-* 显式开，避免误装。

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

WBC_TARGET="${WBC_TARGET:-${WBC_DIR:-${HOME}/VLA/GR00T-WholeBodyControl}}"
WBC_URL="${WBC_URL:-git@github.com:NVlabs/GR00T-WholeBodyControl.git}"

usage() {
    cat <<EOF
用法: bash recipes/gr00t_sonic/setup.sh [--clone-only] [--install-sim] [--install-collect] [--install-infer] [--download-sonic]

  --clone-only       只保证 ~/VLA/GR00T-WholeBodyControl 存在
  --install-sim      bash install 仿真依赖（.venv_sim）
  --install-collect  install_data_collection.sh（不含 PICO APK）
  --install-pico     install_pico.sh（要 PICO 4 / 4 Pro）
  --install-infer    install_inference.sh
  --download-sonic   python download_from_hf.py（按 SONIC_VARIANT）

默认 --clone-only。TensorRT 版本：x86 必须 10.13；G1 Orin 必须 10.7 + JetPack 6。
EOF
}

DO_CLONE=1
DO_SIM=0
DO_COLLECT=0
DO_PICO=0
DO_INFER=0
DO_DL=0

if [ "$#" -eq 0 ]; then
    DO_CLONE=1
fi
while [ "$#" -gt 0 ]; do
    case "$1" in
        --clone-only) DO_CLONE=1; shift ;;
        --install-sim) DO_SIM=1; shift ;;
        --install-collect) DO_COLLECT=1; shift ;;
        --install-pico) DO_PICO=1; shift ;;
        --install-infer) DO_INFER=1; shift ;;
        --download-sonic) DO_DL=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "未知参数: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [ ! -d "${WBC_TARGET}/gear_sonic" ]; then
    if [ -d "${WBC_TARGET}" ] && [ -z "$(ls -A "${WBC_TARGET}" 2>/dev/null || true)" ]; then
        rmdir "${WBC_TARGET}" || true
    fi
    if [ -d "${WBC_TARGET}/.git" ] && [ ! -d "${WBC_TARGET}/gear_sonic" ]; then
        echo "[setup] clone 未完成: ${WBC_TARGET}。等 git 结束或删掉重来。" >&2
        exit 1
    fi
    echo "[setup] clone ${WBC_URL} -> ${WBC_TARGET}"
    mkdir -p "$(dirname "${WBC_TARGET}")"
    GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 "${WBC_URL}" "${WBC_TARGET}"
else
    echo "[setup] 已有 ${WBC_TARGET}"
fi

WBC_DIR="${WBC_TARGET}"
cd "${WBC_DIR}"

if [ "${DO_SIM}" = "1" ]; then
    bash install_scripts/install_mujoco_sim.sh
fi

if [ "${DO_COLLECT}" = "1" ]; then
    bash install_scripts/install_data_collection.sh
fi
if [ "${DO_PICO}" = "1" ]; then
    bash install_scripts/install_pico.sh
fi
if [ "${DO_INFER}" = "1" ]; then
    bash install_scripts/install_inference.sh
fi
if [ "${DO_DL}" = "1" ]; then
    bash "${SCRIPT_DIR}/download_sonic.sh"
fi

echo
echo "[setup] Isaac-GR00T: ${GR00T_DIR:-MISSING}"
echo "[setup] WholeBodyControl: ${WBC_DIR}"
echo "[setup] 下一步:"
echo "  bash ${SCRIPT_DIR}/check.sh"
echo "  bash ${SCRIPT_DIR}/collect.sh --sim --prompt 'pick up the cookie box'"
echo "  bash ${SCRIPT_DIR}/train.sh --dataset-path /path/to/cleaned"
echo "  bash ${SCRIPT_DIR}/server.sh /path/to/checkpoint-20000"
echo "  bash ${SCRIPT_DIR}/infer.sh --sim --prompt 'pick up the cookie box'"
