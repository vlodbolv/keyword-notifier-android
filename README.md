# 🔔 Keyword Notifier

Keyword Notifier is a privacy-focused Flutter utility app designed to monitor your Android system notifications in the background. It scans incoming alerts for specific user-defined keywords (e.g., "OTP", "Urgent", "Server Down") and creates a persistent log of matches, ensuring you never miss critical information buried in your notification shade.

## 🎯 Function & Purpose

The primary purpose of this application is **Automated Notification Filtering and Logging**.

### Key Capabilities

- **Background Monitoring**: Runs a lightweight background service (using Dart Isolates) to listen to notifications even when the app is closed.
- **Privacy-First**: All processing happens locally on the device. No data is sent to the cloud.
- **Infinite Loop Protection**: Smart detection prevents the app from triggering notifications on its own alerts.
- **Persistent History**: Logs matches with timestamps, app source, and content, viewable in a clean history list.
- **Swipe Management**: Easily manage your history with swipe-to-delete functionality.

## 🛠️ Development Environment Setup

This project uses Distrobox to create an isolated, reproducible development environment based on Ubuntu 24.04. This ensures that the host system remains clean while providing all the complex dependencies required for Android/Flutter development (Java, CMake, 32-bit libraries, etc.).

### Prerequisites

- Distrobox installed on your host machine.
- Podman or Docker installed.

### Step 1: Create the Container

We use a helper script to create the container with the specific flags required for USB debugging (connecting physical Android phones) and user permissions.

1. Make the creation script executable:

```bash
chmod +x create_flutter_distrobox.sh
```

2. Run the script:

```bash
./create_flutter_distrobox.sh
```

**What this does**: It initializes a container named `flutter-dev` using the `ubuntu:24.04` image.

**Critical Flags**: It maps USB devices (`--device /dev/bus/usb/...`) to allow adb to see your physical phone from inside the container.

### Step 2: Install Dependencies

Once the container is created, you must install the Android toolchain and Linux build tools. We have automated this process.

1. Enter the container:

```bash
distrobox enter flutter-dev
```

2. Run the dependency installer (inside the container):

```bash
chmod +x install_dependencies_inside_distrobox.sh
./install_dependencies_inside_distrobox.sh
```

This script automatically handles:

- **System Tools**: curl, git, unzip, xz-utils.
- **Android Runtime**: Installs necessary 32-bit libraries (`libglu1-mesa:i386`, `libc6-i386`) required by the Android SDK.
- **Linux Desktop Support**: Installs `libgtk-3-dev`, `ninja-build`, and `clang` for building the Linux version of the app.
- **CMake**: Downloads and installs CMake 4.2.3 manually to ensure compatibility.
- **Android SDK**: Automatically downloads `commandlinetools-linux` and organizes the folder structure under `~/Android/Sdk`.

### Step 3: Install Flutter SDK

The dependency script configures your PATH for Flutter, but you need to clone the repo manually inside the container:

```bash
# Inside the container
cd ~
git clone https://github.com/flutter/flutter.git -b stable

# Reload your shell configuration
source ~/.bashrc

# Accept Android Licenses
flutter doctor --android-licenses
```

## 🚀 Running the App

### 1. Connect a Device

Connect your Android phone via USB. Ensure "USB Debugging" is enabled on the phone.

Inside the container, run:

```bash
flutter devices
```

If your setup is correct, you should see your device listed.

### 2. Run

```bash
flutter run
```

### 3. Grant Permissions (Critical)

Upon first launch on your Android device:

1. Tap the **Enable** switch in the app.
2. You will be redirected to Android Settings (**Special App Access > Device & App Notifications**).
3. Find **Keyword Notifier** and toggle it **ON**.
4. Return to the app; it is now listening.

## 📂 Project Structure

- `lib/main.dart`: Entry point.
- `lib/services/`: Background service logic (Isolates).
- `lib/providers/`: State management (AppState).
- `lib/screens/`: UI views (HomeScreen, HistoryView, KeywordsView).
- `create_flutter_distrobox.sh`: Host script to create the environment.
- `install_dependencies_inside_distrobox.sh`: Container script to install SDKs.
