#!/usr/bin/env bash
# Complete Flutter + Android Studio Dependencies - Ubuntu 24.04 Noble (Distrobox)
# Includes CMake 4.2.3, sdkmanager fix, all flutter doctor resolutions
# Run INSIDE flutter-dev: distrobox enter flutter-dev

set -euo pipefail

echo "=== 1. System Update & i386 Arch ==="
sudo apt update && sudo apt upgrade -y
sudo dpkg --add-architecture i386
sudo apt update

echo "=== 2. software-properties-common (add-apt-repository) ==="
sudo apt install -y software-properties-common

echo "=== 3. Flutter Core Dependencies ==="
sudo apt install -y \
    curl git unzip xz-utils zip wget \
    libglu1-mesa libglu1-mesa:i386 lib32z1 libgomp1:i386

echo "=== 4. Android Studio Runtime ==="
sudo apt install -y \
    libc6-i386 libstdc++6:i386 libncurses6 libncurses-dev \
    libbz2-1.0 libglib2.0-bin build-essential libxft2 \
    libnotify-bin xvfb qemu-system-x86 qemu-utils

echo "=== 5. Linux Desktop Tools + Universe Repo ==="
sudo add-apt-repository universe -y
sudo apt update
sudo apt install -y \
    clang ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev

echo "=== 6. Chromium for Web Development ==="
sudo apt install -y chromium-browser
echo 'export CHROME_EXECUTABLE=/usr/bin/chromium-browser' >> ~/.bashrc

echo "=== 7. CMake 4.2.3 (User ~/cmake) ==="
cd /tmp
wget https://cmake.org/files/v4.2/cmake-4.2.3-linux-x86_64.tar.gz
tar xzf cmake-4.2.3-linux-x86_64.tar.gz
mkdir -p ~/cmake && rm -rf ~/cmake/*
mv cmake-4.2.3-linux-x86_64/* ~/cmake/
rm -rf cmake-4.2.3-linux-x86_64 *.tar.gz
echo 'export PATH="$HOME/cmake/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/cmake/bin:$PATH"
echo "=== 8. Flutter PATH Setup ==="
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc

echo "=== 9. Android SDK + Cmdline-Tools Auto-Download ==="
export ANDROID_HOME="$HOME/Android/Sdk"
mkdir -p "$ANDROID_HOME/cmdline-tools"
if [ ! -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    cd /tmp
    LATEST_CMDLINE=$(curl -s "https://developer.android.com/studio#command-line-tools-only" | grep -oP 'commandlinetools-linux-\K[0-9.]+(?=\.zip)' | head -1)
    wget "https://dl.google.com/android/repository/commandlinetools-linux-${LATEST_CMDLINE:-13.0.zip}" -O cmdline-tools.zip
    unzip cmdline-tools.zip
    mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
    mv cmdline-tools/* "$ANDROID_HOME/cmdline-tools/latest/"
    rm -rf cmdline-tools cmdline-tools.zip
    chmod +x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
fi
echo "export ANDROID_HOME=\"$HOME/Android/Sdk\"" >> ~/.bashrc
echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"' >> ~/.bashrc

echo "✅ ALL DEPENDENCIES INSTALLED!"
echo "Reload: source ~/.bashrc"
echo "Verify: flutter doctor -v"
echo "Licenses: flutter doctor --android-licenses"
echo "Export apps: distrobox-export --app flutter --app android-studio"

