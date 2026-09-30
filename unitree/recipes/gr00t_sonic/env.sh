# G1 SONIC / GR00T N1.7 — 采集 / 训练 / 推理共用路径。
# 本文件在 Isaac-GR00T 的 unitree/recipes/gr00t_sonic/ 下。
# 训练和 PolicyServer 就是这份 Isaac-GR00T。采集和 C++ 全身控制在
# third_party/GR00T-WholeBodyControl，或推理机上的 yvshu 树。

set -euo pipefail

_RECIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# unitree/recipes/gr00t_sonic -> 仓库根
REPO_ROOT="$(cd "${_RECIPE_DIR}/../../.." && pwd)"

resolve_dir() {
    local env_name="$1"
    shift
    if [ -n "${!env_name:-}" ] && [ -d "${!env_name}" ]; then
        printf '%s\n' "${!env_name}"
        return 0
    fi
    local d
    for d in "$@"; do
        if [ -d "${d}" ]; then
            printf '%s\n' "${d}"
            return 0
        fi
    done
    return 1
}

GR00T_DIR="$(resolve_dir GR00T_DIR \
    "${REPO_ROOT}" \
    "/home/zsj/workspace/yvshu/Isaac-GR00T" \
    "${HOME}/VLA/Isaac-GR00T" \
    "${HOME}/unitree_g1/VLA/Isaac-GR00T" \
    "${HOME}/Isaac-GR00T" || true)"
WBC_DIR="$(resolve_dir WBC_DIR \
    "${REPO_ROOT}/third_party/GR00T-WholeBodyControl" \
    "/home/zsj/workspace/yvshu/GR00T-WholeBodyControl" \
    "${HOME}/VLA/GR00T-WholeBodyControl" \
    "${HOME}/unitree_g1/VLA/GR00T-WholeBodyControl" \
    "${HOME}/GR00T-WholeBodyControl" || true)"

# 官方 PolicyServer 教程端口 5550；TongBot 双臂 GR00T 占用 5555，不要混。
export POLICY_PORT="${POLICY_PORT:-5550}"
export POLICY_HOST="${POLICY_HOST:-127.0.0.1}"
export EMBODIMENT_TAG="${EMBODIMENT_TAG:-UNITREE_G1_SONIC}"
export G1_CAMERA_HOST="${G1_CAMERA_HOST:-192.168.123.164}"
export G1_CAMERA_PORT="${G1_CAMERA_PORT:-5555}"

# default | v1.1 | low_latency —— 采集和上机必须同一套
export SONIC_VARIANT="${SONIC_VARIANT:-v1.1}"

gr00t_python() {
    if [ -n "${GR00T_PYTHON:-}" ] && [ -x "${GR00T_PYTHON}" ]; then
        printf '%s\n' "${GR00T_PYTHON}"
        return 0
    fi
    if [ -n "${GR00T_DIR}" ] && [ -x "${GR00T_DIR}/.conda/bin/python" ]; then
        printf '%s\n' "${GR00T_DIR}/.conda/bin/python"
        return 0
    fi
    if [ -n "${GR00T_DIR}" ] && [ -x "${GR00T_DIR}/.venv/bin/python" ]; then
        printf '%s\n' "${GR00T_DIR}/.venv/bin/python"
        return 0
    fi
    return 1
}

sonic_ckpt_args() {
    # deploy.sh --cp 是前缀，会自己拼 _encoder.onnx / _decoder.onnx
    case "${SONIC_VARIANT}" in
        default)
            printf '%s\n' \
                --deploy-checkpoint policy/release/model \
                --deploy-obs-config policy/release/observation_config.yaml
            ;;
        v1.1)
            printf '%s\n' \
                --deploy-checkpoint policy/sonic_v1_1/model \
                --deploy-obs-config policy/sonic_v1_1/observation_config.yaml \
                --deploy-motor-kp-scale 4,10=1.5 \
                --deploy-motor-kd-scale 4,10=1.5
            ;;
        low_latency)
            printf '%s\n' \
                --deploy-checkpoint policy/low_latency/model \
                --deploy-obs-config policy/low_latency/observation_config.yaml
            ;;
        *)
            echo "[gr00t_sonic] 未知 SONIC_VARIANT=${SONIC_VARIANT}（default|v1.1|low_latency）" >&2
            return 1
            ;;
    esac
}

require_gr00t() {
    if [ -z "${GR00T_DIR}" ] || [ ! -d "${GR00T_DIR}" ]; then
        echo "[gr00t_sonic] 找不到 Isaac-GR00T。clone tongbot 分支到 ~/VLA/Isaac-GR00T" >&2
        echo "  git clone -b tongbot git@github.com:qiaow371/Isaac-GR00T.git ~/VLA/Isaac-GR00T" >&2
        exit 1
    fi
}

require_wbc() {
    if [ -z "${WBC_DIR}" ] || [ ! -d "${WBC_DIR}/gear_sonic" ]; then
        echo "[gr00t_sonic] 找不到 GR00T-WholeBodyControl。先跑:" >&2
        echo "  bash ${_RECIPE_DIR}/setup.sh" >&2
        exit 1
    fi
}

require_wbc_script() {
    local rel="$1"
    require_wbc
    if [ ! -f "${WBC_DIR}/${rel}" ]; then
        echo "[gr00t_sonic] 缺 ${WBC_DIR}/${rel}" >&2
        exit 1
    fi
}
