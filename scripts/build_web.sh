#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Installing Flutter ${FLUTTER_CHANNEL:-stable}..."
  if [ ! -d ".flutter" ]; then
    git clone --depth 1 --branch "${FLUTTER_CHANNEL:-stable}" https://github.com/flutter/flutter.git .flutter
  fi
  export PATH="$PWD/.flutter/bin:$PATH"
fi

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}" \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY:-}"
