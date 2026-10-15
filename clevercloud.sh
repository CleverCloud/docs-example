#!/usr/bin/env bash
# Clever Cloud helper for the Docs backend (Python runtime).
# Maps the linked add-on variables to the names expected by Docs, then runs
# the database migrations (build hook) or starts the ASGI server (run command).
set -eu

export DATABASE_URL="${POSTGRESQL_ADDON_URI}"
export AWS_S3_ENDPOINT_URL="https://${CELLAR_ADDON_HOST}"
export AWS_S3_ACCESS_KEY_ID="${CELLAR_ADDON_KEY_ID}"
export AWS_S3_SECRET_ACCESS_KEY="${CELLAR_ADDON_KEY_SECRET}"

mkdir -p "${DATA_DIR}"

if [[ -d src/backend ]]; then
  cd src/backend
fi

case "${1:-}" in
  migrate)
    uv run python manage.py migrate --no-input
    ;;
  run)
    uv run uvicorn --host 0.0.0.0 --port "${PORT:-8080}" --timeout-graceful-shutdown 300 --limit-max-requests 20000 --lifespan off impress.asgi:application
    ;;
  *)
    printf 'Usage: %s migrate|run\n' "$0" >&2
    exit 1
    ;;
esac
