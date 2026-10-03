#!/usr/bin/env bash
# Run every marimo notebook in lectures/ and save its outputs to __marimo__/session/,
# so the molab preview shows charts and numbers before anyone presses Run.
set -euo pipefail
cd "$(dirname "$0")/.."
uv run -q --with marimo --with numpy --with pandas --with altair \
  marimo export session lectures/ --force-overwrite
