#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_RUNNER="$ROOT_DIR/scripts/run_backend.sh"
FRONTEND_RUNNER="$ROOT_DIR/scripts/run_frontend.sh"
NEO4J_STARTER="$ROOT_DIR/scripts/start-neo4j.sh"
NEO4J_WAIT_MAX=45
FRONTEND_WAIT_MAX=180

cleanup() {
  local exit_code=$?
  if [[ -n "${NGROK_PID:-}" ]] && kill -0 "$NGROK_PID" 2>/dev/null; then
    kill "$NGROK_PID" 2>/dev/null || true
  fi
  if [[ -n "${BACKEND_PID:-}" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
  if [[ -n "${FRONTEND_PID:-}" ]] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
    kill "$FRONTEND_PID" 2>/dev/null || true
  fi
  exit "$exit_code"
}
trap cleanup INT TERM

echo
echo "===================================================="
echo "  BlueGuard - ngrok Startup (Linux)"
echo "===================================================="
echo

if [[ ! -x "$BACKEND_RUNNER" ]]; then
  echo "[ERROR] Missing or not executable: $BACKEND_RUNNER"
  exit 1
fi

if [[ ! -x "$FRONTEND_RUNNER" ]]; then
  echo "[ERROR] Missing or not executable: $FRONTEND_RUNNER"
  exit 1
fi

if ! command -v ngrok >/dev/null 2>&1; then
  echo "[ERROR] ngrok not installed or not in PATH"
  echo "Install from: https://ngrok.com/download"
  exit 1
fi

echo "[OK] ngrok is installed"

if [[ -x "$NEO4J_STARTER" ]]; then
  "$NEO4J_STARTER" auto "$NEO4J_WAIT_MAX"
else
  echo "[WARN] Neo4j starter not found: $NEO4J_STARTER"
  echo "[WARN] Continuing startup. QA graph features may be degraded."
fi

echo "[*] Starting backend service..."
"$BACKEND_RUNNER" &
BACKEND_PID=$!

sleep 3

echo "[*] Starting frontend service..."
"$FRONTEND_RUNNER" &
FRONTEND_PID=$!

echo "[*] Waiting for frontend port 5173 (max ${FRONTEND_WAIT_MAX}s)..."
for ((i=1; i<=FRONTEND_WAIT_MAX; i++)); do
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn | awk '{print $4}' | grep -qE ':5173$'; then
      echo "[OK] Frontend is listening on 5173, starting ngrok."
      break
    fi
  else
    if netstat -ltn 2>/dev/null | awk '{print $4}' | grep -qE ':5173$'; then
      echo "[OK] Frontend is listening on 5173, starting ngrok."
      break
    fi
  fi

  if (( i == FRONTEND_WAIT_MAX )); then
    echo "[WARN] Frontend not ready within timeout, ngrok will still be started."
  fi
  sleep 1
done

echo "[*] Starting ngrok tunnel to port 5173..."
ngrok http 5173 &
NGROK_PID=$!

echo
echo "Services started:"
echo "Local app: http://localhost:5173"
echo "ngrok URL: see ngrok terminal output"
echo
echo "Press Ctrl+C to stop backend/frontend/ngrok."
wait "$BACKEND_PID" "$FRONTEND_PID" "$NGROK_PID"
