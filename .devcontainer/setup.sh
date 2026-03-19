#!/usr/bin/env bash
set -euo pipefail

echo "=== LeoBook Codespace Auto-Setup (API 36) ==="

# ---- 0. Install system dependencies ----
echo "[0/8] Installing system dependencies..."
apt-get update -qq && apt-get install -y -qq chromium-browser wget unzip > /dev/null 2>&1 || true

# ---- 1. Python Dependencies ----
echo "[1/8] Installing Python dependencies..."
pip install --upgrade pip -q 2>/dev/null || true
[ -f requirements.txt ] && pip install -r requirements.txt -q || true
[ -f requirements-rl.txt ] && pip install -r requirements-rl.txt -q || true

# ---- 2. Playwright ----
echo "[2/8] Installing Playwright browsers..."
python -m playwright install-deps 2>/dev/null || true
python -m playwright install chromium 2>/dev/null || true

# ---- 3. Create Data Directories ----
echo "[3/8] Creating data directories..."
mkdir -p Data/Store/{models,Assets}
mkdir -p Data/Store/crests/{teams,leagues,flags}
mkdir -p Modules/Assets/{logos,crests}

# ---- 4. Flutter SDK ----
echo "[4/8] Installing Flutter SDK..."
if [ ! -d "$HOME/flutter" ]; then
    git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter" --depth 1 2>/dev/null || true
fi
export PATH="$PATH:$HOME/flutter/bin"
grep -q 'flutter/bin' ~/.bashrc || echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
$HOME/flutter/bin/flutter --version 2>/dev/null || true

# ---- 5. Android SDK (Manual Installation) ----
echo "[5/8] Installing Android SDK..."
export ANDROID_HOME="$HOME/android-sdk"
mkdir -p "$ANDROID_HOME"

# Download and install Android SDK Command-line Tools
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
    echo "  Downloading Android SDK tools..."
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    cd /tmp
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip 2>/dev/null || true
    unzip -q cmdline-tools.zip -d "$ANDROID_HOME/cmdline-tools/" 2>/dev/null || true
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" 2>/dev/null || true
    rm -f cmdline-tools.zip
    cd - > /dev/null
fi

export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

# Accept licenses and install components
echo "  Configuring Android SDK..."
mkdir -p "$ANDROID_HOME/licenses"
echo -e "\n24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$ANDROID_HOME/licenses/android-sdk-license"
echo -e "\nd56f5187479451eabf01fb78af6dfcb131b33910" >> "$ANDROID_HOME/licenses/android-sdk-license"

# Install platform and build tools
if command -v sdkmanager &> /dev/null; then
    echo "  Installing platforms and build-tools..."
    sdkmanager "platform-tools" "platforms;android-36" "build-tools;35.0.0" > /dev/null 2>&1 || true
    sdkmanager "emulator" > /dev/null 2>&1 || true
fi

# ---- 6. Flutter Configuration ----
echo "[6/8] Configuring Flutter..."
$HOME/flutter/bin/flutter config --android-sdk "$ANDROID_HOME" 2>/dev/null || true
$HOME/flutter/bin/flutter precache 2>/dev/null || true

# ---- 7. Flutter App Dependencies & Gradle Update ----
echo "[7/8] Updating Flutter project..."
if [ -d "leobookapp" ]; then
    cd leobookapp
    find . -name "build.gradle" -type f -exec sed -i 's/compileSdk .*/compileSdk 36/' {} + 2>/dev/null || true
    find . -name "build.gradle" -type f -exec sed -i 's/targetSdk .*/targetSdk 36/' {} + 2>/dev/null || true
    
    $HOME/flutter/bin/flutter pub get 2>/dev/null || true
    cd ..
fi

# ---- 8. VS Code Settings ----
echo "[8/8] Configuring VS Code..."
mkdir -p .vscode
[ ! -f .vscode/settings.json ] && cat > .vscode/settings.json << 'EOF'
{
  "python.terminal.useEnvFile": true,
  "[python]": {
    "editor.defaultFormatter": "ms-python.python",
    "editor.formatOnSave": true
  }
}
EOF

# Export paths for current session
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$HOME/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

echo ""
echo "============================================"
echo "  ✓ LeoBook Setup Complete!"
echo "============================================"
echo "  Android SDK: $ANDROID_HOME"
echo "  Flutter: $HOME/flutter"
echo "  API Level: 36 (compileSdk)"
echo ""