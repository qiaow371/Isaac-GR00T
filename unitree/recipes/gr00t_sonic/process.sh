#!/usr/bin/env bash
# process_dataset.py：删丢弃条。VR_3PT 加 --no-remove-stale-smpl。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"
require_wbc_script gear_sonic/scripts/process_dataset.py

IN=""
OUT=""
NO_STALE=0
EXTRA=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dataset-path|--in) IN="$2"; shift 2 ;;
        --output-path|--out) OUT="$2"; shift 2 ;;
        --no-remove-stale-smpl) NO_STALE=1; shift ;;
        *) EXTRA+=("$1"); shift ;;
    esac
done

if [ -z "${IN}" ] || [ -z "${OUT}" ]; then
    echo "用法: bash process.sh --dataset-path <raw> --output-path <cleaned> [--no-remove-stale-smpl]" >&2
    exit 1
fi

cd "${WBC_DIR}"
if [ -x .venv_data_collection/bin/python ]; then
    # shellcheck disable=SC1091
    source .venv_data_collection/bin/activate
fi

CMD=(python gear_sonic/scripts/process_dataset.py
    --dataset-path "${IN}"
    --output-path "${OUT}")
if [ "${NO_STALE}" = "1" ]; then
    CMD+=(--no-remove-stale-smpl)
fi
CMD+=("${EXTRA[@]}")
echo "[process] ${CMD[*]}"
exec "${CMD[@]}"
