# 🔔 Keyword Notifier

**Keyword Notifier** is a privacy-focused Flutter utility designed to monitor Android system notifications in the background. By scanning incoming alerts for user-defined keywords (e.g., "OTP", "Urgent", "Server Down"), the app creates a persistent local log, ensuring you never miss critical information buried in a crowded notification shade.

---

## 🎯 Function & Purpose

The primary objective of this application is **Automated Notification Filtering and Logging**.

### Key Capabilities

* **Background Monitoring**: Utilizes a lightweight background service via **Dart Isolates** to listen for notifications even when the app is terminated.
* **Privacy-First Architecture**: All processing occurs locally on-device. No notification data ever leaves your hardware.
* **Infinite Loop Protection**: Integrated smart detection prevents the app from re-triggering notifications based on its own generated alerts.
* **Persistent History**: Logs matches with precise timestamps, source application details, and content.
* **Intuitive UX**: Easily manage your monitored keywords and swipe-to-delete history logs.

---

## 🛠️ Development Environment Setup

This project utilizes **Distrobox** to provide an isolated, reproducible development environment based on **Ubuntu 24.04**. This ensures your host system remains clean while satisfying the complex dependencies required for Android and Flutter development.

### Prerequisites

* **Distrobox** installed on the host machine.
* **Podman** or **Docker** backend.

### Step 1: Create the Container

We use a helper script to initialize the container with the specific flags required for USB debugging and device permissions.

1. **Make the script executable**:
```bash
chmod +x create_flutter_distrobox.sh

```


2. **Run the script**:
```bash
./create_flutter_distrobox.sh

```


* **What this does**: Initializes a container named `flutter-dev` using `ubuntu:24.04`.
* **Critical Flags**: Maps USB devices (`--device /dev/bus/usb/...`) to allow `adb` to detect physical devices from within the container.



### Step 2: Install Dependencies

Once the container is active, you must install the Android toolchain and Linux build tools.

1. **Enter the container**:
```bash
distrobox enter flutter-dev

```


2. **Run the automated installer**:
```bash
chmod +x install_dependencies_inside_distrobox.sh
./install_dependencies_inside_distrobox.sh

```



**Included in this step**:

* **Android Runtime**: 32-bit libraries (`libglu1-mesa:i386`, `libc6-i386`) for the SDK.
* **Desktop Support**: `libgtk-3-dev`, `ninja-build`, and `clang` for Linux builds.
* **Build Tools**: Manual installation of **CMake 4.2.3** and Android **commandlinetools**.

### Step 3: Install Flutter SDK

Configure your path and fetch the stable Flutter branch:

```bash
# Inside the container
cd ~
git clone https://github.com/flutter/flutter.git -b stable

# Reload shell configuration
source ~/.bashrc

# Accept Android Licenses
flutter doctor --android-licenses

```

---

## 🚀 Running the App

### 1. Connect a Device

Connect your Android phone via USB and ensure **USB Debugging** is enabled. Inside the container, verify the connection:

```bash
flutter devices

```

### 2. Launch

```bash
flutter run

```

### 3. Grant Permissions (Mandatory)

Upon first launch, you must manually grant access to the notification stream:

1. Toggle the **Enable** switch in the app.
2. You will be redirected to **Special App Access > Device & App Notifications**.
3. Locate **Keyword Notifier** and toggle it **ON**.

---

## 📂 Project Structure

```text
lib/
├── main.dart           # Entry point & Theme configuration
├── services/           # Background service logic & Isolates
├── providers/          # State management (AppState)
└── screens/            # UI (HomeScreen, HistoryView, KeywordsView)
scripts/
├── create_flutter_distrobox.sh           # Host-side initialization
└── install_dependencies_inside_distrobox.sh # Container-side SDK setup

```
