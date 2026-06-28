#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.27.4}"
FLUTTER_INSTALL_DIR="${VERCEL_CACHE_DIR:-$PWD/.cache}/flutter"
FLUTTER_BIN="$FLUTTER_INSTALL_DIR/bin/flutter"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Installing Flutter $FLUTTER_VERSION..."
  mkdir -p "$(dirname "$FLUTTER_INSTALL_DIR")"

  if [ ! -x "$FLUTTER_BIN" ]; then
    rm -rf "$FLUTTER_INSTALL_DIR"
    git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_INSTALL_DIR"
  fi

  export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}" \
  --dart-define=OSRM_BASE_URL="${OSRM_BASE_URL:-https://router.project-osrm.org}"
