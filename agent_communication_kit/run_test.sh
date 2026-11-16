#!/bin/bash
set -euo pipefail
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
if ! command -v python3 >/dev/null; then echo '需要 Python 3.9 或更高版本。' >&2; exit 1; fi
if [ ! -x "$KIT_DIR/.venv/bin/python" ]; then
  echo '首次运行：创建本工具专用 Python 环境，并安装报告依赖…'
  python3 -m venv "$KIT_DIR/.venv"
fi
if ! "$KIT_DIR/.venv/bin/python" -c 'import docx' >/dev/null 2>&1; then
  "$KIT_DIR/.venv/bin/python" -m pip install -r "$KIT_DIR/requirements.txt"
fi
exec "$KIT_DIR/.venv/bin/python" "$KIT_DIR/agent_experiment.py" "$@"
