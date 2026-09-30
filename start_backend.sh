#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SERVER_DIR="$PROJECT_DIR/server"
VENV_DIR="$SERVER_DIR/.venv"
PYTHON_BIN="${PYTHON_BIN:-python3}"
BACKEND_HOST="${RESUMER_BACKEND_HOST:-0.0.0.0}"
BACKEND_PORT="${RESUMER_BACKEND_PORT:-8000}"
ENABLE_RELOAD="${RESUMER_BACKEND_RELOAD:-true}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Error: $PYTHON_BIN was not found. Install Python 3.11 or newer." >&2
  exit 1
fi

if ! "$PYTHON_BIN" -c \
  "import sys; raise SystemExit(sys.version_info < (3, 11))"; then
  echo "Error: Resumer's backend requires Python 3.11 or newer." >&2
  exit 1
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  echo "Creating backend virtual environment..."
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -c \
  "import fastapi, httpx, dotenv, pydantic, uvicorn" >/dev/null 2>&1; then
  echo "Installing backend dependencies..."
  "$VENV_DIR/bin/python" -m pip install --editable "$SERVER_DIR"
fi

if [[ ! -f "$SERVER_DIR/.env" ]]; then
  cp "$SERVER_DIR/.env.example" "$SERVER_DIR/.env"
  echo "Created server/.env from .env.example."
  echo "Add GEMINI_API_KEY to server/.env to enable AI tailoring."
fi

uvicorn_args=(
  "resumer_api.main:app"
  "--app-dir" "$SERVER_DIR"
  "--host" "$BACKEND_HOST"
  "--port" "$BACKEND_PORT"
)

case "$ENABLE_RELOAD" in
  1|true|TRUE|yes|YES|on|ON) uvicorn_args+=("--reload") ;;
esac

echo "Starting Resumer backend at http://$BACKEND_HOST:$BACKEND_PORT"
exec "$VENV_DIR/bin/python" -m uvicorn "${uvicorn_args[@]}" "$@"
