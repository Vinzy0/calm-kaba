
# Anxiety Symptom Screening and Support Application

The Android camera and seven-model integration, build instructions, numerical
verification, and phone checklist are documented in [CAMERA_INTEGRATION.md](CAMERA_INTEGRATION.md).

## Personal repository

This private copy belongs to [Vinzy0/calm-kaba](https://github.com/Vinzy0/calm-kaba).
The original app is [kiri-ye/calm-kaba](https://github.com/kiri-ye/calm-kaba).
The original repository is available locally as `upstream`, with pushing disabled.

| Branch | Models |
| --- | --- |
| `codex/camera-behavior-integration` | Seven full-feature models, each symptom vs everything else |
| `codex/restricted-vs-control` | Seven symptom-restricted models, each symptom vs control |

The deployable model and tracking assets are included. Participant datasets,
recorded research fixtures and local verification files are excluded.

## Overview

Calm Kaba is a Flutter Android application that detects selected behavioral indicators using MediaPipe landmarks and seven independent LightGBM classifiers.

The application aims to help users explore selected behavioral patterns, access educational information about anxiety-related symptoms, and learn coping techniques that may support their well-being.

**This application is a screening and informational tool, not a diagnostic tool.** Its results do not confirm or rule out an anxiety disorder and should not replace professional assessment or healthcare.

## Features

- **Behavioral detection** analyzes camera landmarks using the seven full-feature vs_everything LightGBM models from the 51-participant run.
- **Screening Results** — Displays the results of the system's analysis.
- **Educational Resources** — Provides information about selected symptoms and their limitations.
- **Coping Techniques** — Offers supportive techniques such as grounding, breathing regulation, and cognitive reframing.
- **Interactive Interface** — Provides a mobile user experience developed using Flutter.
- **Responsible Use Information** — Explains the limitations of automated screening and the importance of professional guidance.

## Technologies Used

- **Flutter** — Cross-platform mobile application framework
- **Dart** — Programming language
- **CameraX and MediaPipe Tasks** supply an Android camera preview, face/iris, pose, hand, blendshape, and transformation-matrix outputs.
- **LightGBM 4.7.0** runs exported native models through JNI, with Kotlin normalization and window features verified against Python.

## Getting Started

### Prerequisites

Install the following tools:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Android Studio](https://developer.android.com/studio)
- Flutter and Dart plugins for Android Studio
- An Android emulator or compatible physical device

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/Vinzy0/calm-kaba.git
   ```

2. Navigate to the project directory:

   ```bash
   cd calm-kaba
   ```

3. Prepare the pinned native library and install dependencies:

   ```bash
   ./tools/setup_native.ps1
   flutter pub get
   ```

4. Check the connected devices:

   ```bash
   flutter devices
   ```

5. Run the application:

   ```bash
   flutter run
   ```

Replace `YOUR-USERNAME` with the GitHub username that owns the repository.

## Project Structure

```text
Thesis_Anxiety/
├── android/               # Android platform files
├── ios/                   # iOS platform files
├── lib/                   # Main Dart application code
├── test/                  # Application tests
├── web/                   # Web platform files
├── windows/               # Windows platform files
├── pubspec.yaml            # Dependencies and project configuration
├── pubspec.lock            # Resolved dependency versions
├── analysis_options.yaml   # Dart analysis rules
└── README.md               # Project documentation
```

## Limitations

- The application does not diagnose anxiety disorders.
- Detection results may be inaccurate or affected by recording conditions.
- Behavioral indicators may differ between individuals and may overlap with other conditions.
- The selected symptoms do not represent every possible manifestation of anxiety.
- Coping techniques may not be suitable for everyone.

Users should consult qualified healthcare professionals regarding concerns about their mental or physical health. The application should not be relied upon during medical or mental health emergencies.

## Privacy and Data Handling

Camera frames and rolling landmark windows stay in memory. The app does not record video or upload camera data. Continuous mode stores detection events locally, including symptom label, timestamp, score, threshold, and model-run identity. A user can export or clear this history in the existing log screen.

Sensitive information, participant recordings, private datasets, API keys, and credentials should not be committed to this repository without appropriate authorization and safeguards.

Document the application's actual data collection, processing, storage, and access practices before distributing it.

## Project Status

This project is under development. Features, model implementation, and supported platforms may change as development and testing progress.

## License

No license has been specified. Unless a license is added, others should not assume they have permission to reuse, modify, or distribute this project's code.
