# 🎵 Album Art Fixer for DAPs & HiBy OS

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com)
[![HiBy R1 Ready](https://img.shields.io/badge/Hardware-HiBy%20R1%20%2F%20DAP%20Tested-FFB74D)](https://store.hiby.com)

A high-performance Android utility engineered to diagnose, fix, and optimize embedded audio album artwork for dedicated Digital Audio Players (DAPs) such as the **HiBy R1**, Shanling, Sony Walkman, Astell&Kern, and Fiio.

---

## 🔍 The Problem

Modern Hi-Res audio files often contain high-resolution artwork embedded as:
- **Progressive JPEGs (SOF2 marker `0xC2`)**
- **4-channel CMYK JPEGs** (causing inverted or corrupt colors)
- **High-resolution uncompressed images (>1500×1500 px)**
- **Embedded PNGs or WebP formats**

Dedicated DAPs like the **HiBy R1** utilize resource-constrained hardware decoders and lightweight embedded Linux/RTOS environments. When fed Progressive JPEGs, CMYK colorspaces, or oversized textures, their hardware decoders fail—resulting in **missing cover art, rendering glitches, or audio player crashes**.

---

## 💡 The Solution

**Album Art Fixer** analyzes audio tags byte-by-byte directly on your Android device or attached micro-SD card:
1. **Binary JPEG Inspection:** Parses SOF (Start of Frame) byte markers without full image decoding to instantly distinguish Baseline Sequential DCT (`0xC0`), Progressive (`0xC2`), Extended (`0xC1`), and CMYK channel counts.
2. **Lossless-Prioritized Normalization:** Transcodes problematic artwork into clean, standard **Baseline sRGB JPEGs**.
3. **Adaptive Downscaling:** Constrains oversized album art to DAP-optimal dimensions (e.g., 800×800 or 1000×1000 px) preserving aspect ratio.
4. **Rust-Powered In-Place Tagging:** Employs high-speed native audio tagging bindings (Lofty / Haudiotagger) to atomically update audio metadata across FLAC, MP3, M4A, OGG, and WAV.
5. **Memory-Safe Architecture:** Generates 96×96 memory-cached previews, preventing Out-Of-Memory (OOM) exceptions even when scanning libraries exceeding 10,000+ lossless tracks.

---

## ✨ Features

- 🎧 **Multi-Format Audio Support:** FLAC, MP3 (ID3v2.3/v2.4), M4A/AAC (`covr`), OGG Vorbis, WAV, and ALAC.
- 🔬 **Accurate Compliance Detection:**
  - `Baseline JPEG`: DAP-compliant (Sequential DCT).
  - `Progressive JPEG`: Flagged for conversion (Hardware killer).
  - `CMYK / Extended JPEG`: Flagged for color space & DCT correction.
  - `PNG / WebP`: Flagged for conversion to universal Baseline JPEG.
  - `Corrupt / Missing`: Gracefully identified and reported.
- 🎯 **Granular Selective Processing:** Choose between fixing the entire library or picking individual problematic tracks via multi-select checkboxes.
- 🔄 **Non-Destructive Backups:** Automatically preserves `.original_artwork` alongside tracks with one-tap batch or single-file restoration.
- 📁 **Folder Cover Export:** Optionally outputs a standardized `cover.jpg` into each album directory for file-browser based DAPs.
- 🔍 **Real-Time Search & Filtering:** Filter by `Needs Fix`, `Compliant`, `Fixed`, or search across file name, song title, artist, and album tags.
- 🛑 **Graceful Cancellation:** Safely halt scans or conversions mid-process without data loss or file corruption.
- 🎨 **Audiophile Dark UI:** Modern Material 3 dark aesthetic with high contrast and responsive feedback.

---

## 🏗️ Architecture & Technical Highlights

```
lib/
├── models/
│   └── audio_item.dart         # Track model, compliance status enum & metadata
├── services/
│   ├── jpeg_analyzer.dart      # Binary SOF marker parser, CMYK detector, sRGB transcoder
│   └── audio_service.dart      # Storage scanner, tag reading/writing & backup engine
└── main.dart                   # Material 3 UI, state management, search & filters
```

### Binary SOF Parser Implementation
Rather than relying on high-level image decoders, the app scans raw JPEG segments:
```dart
// Byte markers in JPEG payload:
// 0xFF, 0xC0 -> SOF0: Baseline Sequential DCT (Compliant)
// 0xFF, 0xC2 -> SOF2: Progressive DCT (Incompatible with HiBy R1)
// Channel count check: 3 components = sRGB/YCbCr, 4 components = CMYK
```

---

## 🚀 Building & Installing

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+ recommended)
- Android SDK 35+ / Target SDK 35
- Java 17 to Java 25 (configured via Gradle Toolchain & Foojay resolver)

### Clone & Run
```bash
git clone https://github.com/Lakhiwal/Album-Art-Fixer.git
cd Album-Art-Fixer

# Install dependencies
flutter pub get

# Build Release APK
flutter build apk --release --target-platform android-arm64

# Install to connected device via ADB
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 📱 Permissions

On Android 11+ (API 30+), the app requests `MANAGE_EXTERNAL_STORAGE` to allow in-place modification of audio tags across internal storage and mounted Micro-SD cards.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
