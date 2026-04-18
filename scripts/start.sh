#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_RUNNER="$ROOT_DIR/scripts/run_backend.sh"
FRONTEND_RUNNER="$ROOT_DIR/scripts/run_frontend.sh"
NEO4J_STARTER="$ROOT_DIR/scripts/start-neo4j.sh"
FRONTEND_WAIT_MAX=120
NEO4J_WAIT_MAX=45

cleanup() {
  local exit_code=$?
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
echo "  BlueGuard Platform - Startup (Linux)"
echo "===================================================="
echo

echo "[*] Checking dependencies..."
if [[ ! -x "$BACKEND_RUNNER" ]]; then
  echo "[ERROR] Missing or not executable: $BACKEND_RUNNER"
  exit 1
fi
echo "[OK] Backend runner found."

if [[ ! -x "$FRONTEND_RUNNER" ]]; then
  echo "[ERROR] Missing or not executable: $FRONTEND_RUNNER"
  exit 1
fi
echo "[OK] Frontend runner found."

if ! command -v python3 >/dev/null 2>&1 && [[ ! -x "$ROOT_DIR/backend/blueguard/bin/python" ]]; then
  echo "[ERROR] Python not found and local virtualenv is missing."
  exit 1
fi
echo "[OK] Python check passed. npm will be checked in frontend process."

echo "[OK] Root: $ROOT_DIR"
echo

if [[ -x "$NEO4J_STARTER" ]]; then
  "$NEO4J_STARTER" auto "$NEO4J_WAIT_MAX"
else
  echo "[WARN] Neo4j starter not found: $NEO4J_STARTER"
  echo "[WARN] Continuing startup. QA graph features may be degraded."
fi
echo

echo "[*] Starting backend on port 8000..."
"$BACKEND_RUNNER" &
BACKEND_PID=$!

sleep 3

echo "[*] Starting frontend on port 5173..."
"$FRONTEND_RUNNER" &
FRONTEND_PID=$!

sleep 5
if [[ ! -d "$ROOT_DIR/frontend/node_modules" ]]; then
  FRONTEND_WAIT_MAX=300
  echo "[INFO] First frontend setup detected. Wait timeout set to 300 seconds."
fi

echo
echo "===================================================="
echo "  Services Started"
echo "===================================================="
echo
echo "Frontend: http://localhost:5173"
echo "Backend : http://localhost:8000"
echo "API Docs: http://localhost:8000/docs"
echo

echo "[*] Waiting for frontend port 5173..."
for ((i=1; i<=FRONTEND_WAIT_MAX; i++)); do
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn | awk '{print $4}' | grep -qE ':5173$'; then
      echo "[OK] Frontend is listening on port 5173."
      break
    fi
  else
    if netstat -ltn 2>/dev/null | awk '{print $4}' | grep -qE ':5173$'; then
      echo "[OK] Frontend is listening on port 5173."
      break
    fi
  fi

  if (( i == FRONTEND_WAIT_MAX )); then
    echo "[WARN] Frontend did not listen on port 5173 within ${FRONTEND_WAIT_MAX} seconds."
    echo "[WARN] Browser will still be opened if possible. Check frontend logs."
  fi
  sleep 1
done

if command -v xdg-open >/dev/null 2>&1; then
  echo "[*] Opening http://localhost:5173"
  xdg-open "http://localhost:5173" >/dev/null 2>&1 || true
fi

echo
echo "Launcher is running. Press Ctrl+C to stop backend/frontend."
wait "$BACKEND_PID" "$FRONTEND_PID"
