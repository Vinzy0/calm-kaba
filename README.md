
# Anxiety Symptom Screening and Support Application

## Overview

Thesis_Anxiety is a Flutter-based mobile application designed to screen for selected anxiety-related behavioral indicators using computer vision and deep learning.

The application aims to help users explore selected behavioral patterns, access educational information about anxiety-related symptoms, and learn coping techniques that may support their well-being.

**This application is a screening and informational tool, not a diagnostic tool.** Its results do not confirm or rule out an anxiety disorder and should not replace professional assessment or healthcare.

## Features

- **Symptom Screening** — Analyzes selected anxiety-related behavioral indicators using a deep learning model.
- **Screening Results** — Displays the results of the system's analysis.
- **Educational Resources** — Provides information about selected symptoms and their limitations.
- **Coping Techniques** — Offers supportive techniques such as grounding, breathing regulation, and cognitive reframing.
- **Interactive Interface** — Provides a mobile user experience developed using Flutter.
- **Responsible Use Information** — Explains the limitations of automated screening and the importance of professional guidance.

## Technologies Used

- **Flutter** — Cross-platform mobile application framework
- **Dart** — Programming language
- **MediaPipe** — Visual landmark and movement feature extraction, where applicable
- **Computer Vision and Deep Learning** — Analysis and classification of selected behavioral indicators

*Update this list to match the libraries and models actually used in the project.*

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
   git clone https://github.com/YOUR-USERNAME/Thesis_Anxiety.git
   ```

2. Navigate to the project directory:

   ```bash
   cd Thesis_Anxiety
   ```

3. Install dependencies:

   ```bash
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

The handling of camera recordings, extracted features, and screening results depends on the application's implementation.

Sensitive information, participant recordings, private datasets, API keys, and credentials should not be committed to this repository without appropriate authorization and safeguards.

Document the application's actual data collection, processing, storage, and access practices before distributing it.

## Project Status

This project is under development. Features, model implementation, and supported platforms may change as development and testing progress.

## License

No license has been specified. Unless a license is added, others should not assume they have permission to reuse, modify, or distribute this project's code.
