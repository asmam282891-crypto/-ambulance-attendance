#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is missing from Replit Secrets}"

exec flutter run \
  --dart-define=SUPABASE_URL=https://vdqsdoyqpxuiiznaruuj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  "$@"