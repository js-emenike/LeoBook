#!/usr/bin/env bash
# deploy_apk.sh — Build, rename, and upload LeoBook APK to Supabase Storage.
#
# Usage:
#   ./deploy_apk.sh                     # Build release APK and upload
#   ./deploy_apk.sh --skip-build        # Upload existing APK (skip build)
#
# Requirements:
#   - flutter CLI in PATH
#   - supabase CLI in PATH (or SUPABASE_ACCESS_TOKEN env var for API upload)
#   - jq (for JSON manipulation)
#
# The script:
#   1. Reads version from pubspec.yaml
#   2. Builds release APK
#   3. Renames to LeoBook-v{VERSION}.apk
#   4. Uploads APK to Supabase Storage bucket 'app-releases'
#   5. Uploads updated metadata.json

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────
SUPABASE_URL="https://jefoqzewyvscdqcpnjxu.supabase.co"
BUCKET="app-releases"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/leobookapp"
PUBSPEC="$APP_DIR/pubspec.yaml"
APK_OUTPUT="$APP_DIR/build/app/outputs/flutter-apk"

# ── Read version from pubspec.yaml ────────────────────────────────────────
VERSION=$(grep '^version:' "$PUBSPEC" | head -1 | sed 's/version: *//;s/+.*//')
if [ -z "$VERSION" ]; then
  echo "❌ Could not read version from $PUBSPEC"
  exit 1
fi
echo "📦 Version: $VERSION"

APK_NAME="LeoBook-v${VERSION}.apk"
LATEST_NAME="LeoBook-latest.apk"
PUBLIC_URL="${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${LATEST_NAME}"

# ── Build ─────────────────────────────────────────────────────────────────
if [ "${1:-}" != "--skip-build" ]; then
  echo "🔨 Building release APK..."
  cd "$APP_DIR"
  flutter build apk --release
  cd "$SCRIPT_DIR"
else
  echo "⏭  Skipping build (--skip-build)"
fi

# ── Rename ────────────────────────────────────────────────────────────────
SOURCE_APK="$APK_OUTPUT/app-release.apk"
if [ ! -f "$SOURCE_APK" ]; then
  echo "❌ APK not found at $SOURCE_APK"
  exit 1
fi

cp "$SOURCE_APK" "$APK_OUTPUT/$APK_NAME"
cp "$SOURCE_APK" "$APK_OUTPUT/$LATEST_NAME"
echo "✅ Renamed → $APK_NAME"

# ── Load Supabase key from .env if not already set ────────────────────────
if [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  ENV_FILE="$APP_DIR/.env"
  if [ -f "$ENV_FILE" ]; then
    # Extract SUPABASE_SERVICE_ROLE_KEY from .env (handles quotes and spaces)
    _KEY=$(grep -E '^SUPABASE_SERVICE_ROLE_KEY=' "$ENV_FILE" | head -1 | sed 's/^SUPABASE_SERVICE_ROLE_KEY=//' | tr -d '"' | tr -d "'" | xargs)
    if [ -n "$_KEY" ]; then
      export SUPABASE_SERVICE_ROLE_KEY="$_KEY"
      echo "🔑 Loaded service role key from .env"
    fi
  fi
fi

if [ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  echo ""
  echo "⚠️  SUPABASE_SERVICE_ROLE_KEY not found in .env or environment."
  echo "   Add it to leobookapp/.env:"
  echo "   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key"
  echo ""
  echo "   Or export it: export SUPABASE_SERVICE_ROLE_KEY='...'"
  echo ""
  exit 1
fi

# Upload APK (as LeoBook-latest.apk — stable URL)
echo "📤 Uploading $LATEST_NAME to Supabase..."
curl -s -X POST \
  "${SUPABASE_URL}/storage/v1/object/${BUCKET}/${LATEST_NAME}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY:-missing}" \
  -H "Content-Type: application/vnd.android.package-archive" \
  -H "x-upsert: true" \
  --data-binary "@$APK_OUTPUT/$LATEST_NAME" \
  -o /dev/null -w "HTTP %{http_code}\n"

# Also upload versioned copy for archive
echo "📤 Uploading $APK_NAME to Supabase..."
curl -s -X POST \
  "${SUPABASE_URL}/storage/v1/object/${BUCKET}/${APK_NAME}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY:-missing}" \
  -H "Content-Type: application/vnd.android.package-archive" \
  -H "x-upsert: true" \
  --data-binary "@$APK_OUTPUT/$APK_NAME" \
  -o /dev/null -w "HTTP %{http_code}\n"

# ── Upload metadata.json ──────────────────────────────────────────────────
METADATA_FILE="$APK_OUTPUT/metadata.json"
cat > "$METADATA_FILE" << EOF
{
  "version": "$VERSION",
  "apk_url": "$PUBLIC_URL",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "📤 Uploading metadata.json..."
curl -s -X POST \
  "${SUPABASE_URL}/storage/v1/object/${BUCKET}/metadata.json" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY:-missing}" \
  -H "Content-Type: application/json" \
  -H "x-upsert: true" \
  --data-binary "@$METADATA_FILE" \
  -o /dev/null -w "HTTP %{http_code}\n"

echo ""
echo "✅ Deploy complete!"
echo "   Version:  $VERSION"
echo "   APK URL:  $PUBLIC_URL"
echo "   Metadata: ${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/metadata.json"
