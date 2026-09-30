#!/usr/bin/env bash
# 把 recipes 里的仿真物体拷进 WholeBodyControl 的 G1 MJCF 目录（include 路径要求同级）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"
require_wbc

G1_MDL="${WBC_DIR}/gear_sonic/data/robot_model/model_data/g1"
CFG_DIR="${WBC_DIR}/gear_sonic/utils/mujoco_sim/wbc_configs"
install -d "${G1_MDL}" "${CFG_DIR}"
cp -f "${SCRIPT_DIR}/sim/scene_pickplace_toy.xml" "${G1_MDL}/scene_pickplace_toy.xml"

BASE_YAML="${CFG_DIR}/g1_29dof_sonic_model12.yaml"
OUT_YAML="${CFG_DIR}/g1_29dof_sonic_pickplace.yaml"
if [ ! -f "${BASE_YAML}" ]; then
    echo "[sim-assets] 缺 ${BASE_YAML}" >&2
    exit 1
fi
python3 - <<PY
from pathlib import Path
src = Path("${BASE_YAML}")
dst = Path("${OUT_YAML}")
text = src.read_text()
old = 'ROBOT_SCENE: "gear_sonic/data/robot_model/model_data/g1/scene_43dof.xml"'
new = 'ROBOT_SCENE: "gear_sonic/data/robot_model/model_data/g1/scene_pickplace_toy.xml"'
if old not in text:
    raise SystemExit("unexpected ROBOT_SCENE line in " + str(src))
dst.write_text(text.replace(old, new, 1))
print("wrote", dst)
PY

echo "[sim-assets] ${G1_MDL}/scene_pickplace_toy.xml"
echo "[sim-assets] 仿真: SONIC_SIM_LOOP_EXTRA='--wbc-version pickplace_toy' 或 infer.sh --sim-scene pickplace"
