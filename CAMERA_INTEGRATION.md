# Original full-feature integration reference

This document records the full-feature / vs_everything build. The current
`codex/restricted-vs-control` branch uses seven restricted / vs_control models and
installs as **Calm Kaba Control**. See [the current branch handoff](RESTRICTED_CONTROL.md)
for its model counts, verification and installation steps. The measurements below
belong to the original build unless repeated in that handoff.

App checkout: `C:\Users\VINZ\Documents\calm-kaba`

Branch: `codex/camera-behavior-integration`. This version is saved in the user's
private personal repository, separate from the original team's repository.

The app uses only the seven **full-feature / vs_everything** bundles from
`2026-10-27_51participants_full_vs_restricted`, trained on 51 participants and
16,057 windows. Each independent binary classifier uses its saved 822-column
schema and threshold of 0.5. Their probabilities do not sum to one.

## Implementation

CameraX supplies an Android preview and a latest-frame analysis buffer. A single
background worker runs MediaPipe face, pose, and hand Tasks, feature extraction,
and native LightGBM inference. The UI receives tracking/status/result packets.
Frames remain in memory and are closed after processing; video is not recorded.

The face task enables all 478 landmarks, 52 blendshapes, and the 4x4 facial
transformation matrix. Java's column-major packed matrix is reconstructed before
using Python's row/column names. Hand assignment minimizes distance to anatomical
pose wrists, rather than trusting mirrored handedness labels. The preview mirrors
the front camera; inference never receives a reflected image. CameraX shares a
ViewPort crop between analysis and preview, and frames rotate to upright before
tracking. Overlay coordinates use that rotated image and a display-only reflection.

The Kotlin adapter and features follow `webcam_core.py` and `common.py`, including
float32 landmark storage and extra-column reductions, float64 signals, missing
values, endpoint-clamped interpolation, population standard deviation, linear
percentiles, Hann-windowed frequency power with DC excluded, and frequency bands
0.15-0.8, 0.8-3.0, and 3.0-9.0 Hz. The tremor band's upper endpoint is inclusive.
Windows resample timestamps to 30 Hz. Scanning settles for one second, collects
four seconds, and advances every two seconds. A processing gap over 500 ms resets
the window. Tracking coverage must reach 50% for the relevant anatomy; fewer than
8 processed FPS makes results unavailable. Tremor results below 20 FPS carry a
warning. Resampling does not count as additional camera observations.

LightGBM 4.7.0 runs through its C API and a small JNI bridge. The exporter calls
`booster_.save_model`, preserving the trained trees. No ONNX/TFLite classifier
conversion, retraining, heuristic replacement, or old/restricted models are used.
Model and tracking-asset checksums are checked at startup.

Instant mode waits for the first valid threshold crossing, stops the camera, and
opens the existing result page. If several classifiers fire in that window, the
highest score chooses the displayed result. Continuous mode displays all seven
window results and saves behavioral events to the existing local history.

Each symptom logs once per sustained episode. It rearms after two consecutive
valid below-threshold windows and at least 30 seconds since its previous event.
Unavailable tracking resets the negative-window count. Restarting a scan starts
a new session. Concurrent history writes are serialized and retain score,
threshold, timestamp, and model-run identity. Older history entries remain readable.

Leaving Home, opening another route, backgrounding, rotating, or pressing Stop
unbinds the camera and discards pending results. Restarting collects a fresh window.
Camera permission results require tapping Scan Now again. Permission denial shows
settings guidance. Existing result/history/coping screens and colors are retained;
the existing fonts are bundled for offline use.

## Verification

| Check | Inputs | Observed maximum difference | Required tolerance |
| --- | --- | --- | --- |
| Native text export vs Python bundle | All 16,057 windows per model, plus 32 missing-feature cases per model | 0 probability difference | 1e-12 absolute |
| Kotlin adapter vs Python | 6 raw-result cases, including reversed hands, missing anatomy, low visibility, and degenerate reference | 2.8412206475124533e-18 | 2e-7 absolute |
| Kotlin features vs Python | 24 recorded-window cases across control and seven categories, including sparse sampling and missing data | 0 on 18,604 finite values; all 1,124 missing values matched | 2e-5 absolute + 2e-6 relative |
| Kotlin features through JNI vs Python | Same 24 windows, all seven models | 0 probability difference | 1e-6 absolute |
| JNI inference vs Python | 144 additional feature vectors, including all-missing and partially missing inputs, all seven models | 0 probability difference | 1e-12 absolute |

The JVM checks use the same Kotlin source and C++ bridge as Android. They establish
feature and inference parity on the host, not ARM hardware or live camera accuracy.
Detailed local evidence is under `.verification/`; recorded fixtures are under
`android/app/src/test/resources/parity/`. Both locations are git-ignored. Research
fixtures go only into the separate instrumentation test APK, not the app APK.

Five Flutter checks cover event cooldown/rearming, simultaneous history writes,
instant threshold behavior and stopping, a result page on a 360x640 viewport,
and the home screen's scan controls.
`flutter analyze --no-pub` passes with no issues. Four JVM tests cover adapter,
feature/JNI parity, rolling-window reset, and unavailable tracking.

Android verification also passed on the local x86_64 Android emulator:

- Gradle's four JVM checks and both Android instrumentation tests passed.
- All 24 recorded cases again matched all finite features exactly, including the
  missing-value mask. Their end-to-end prediction difference was zero.
- The 144 extra feature vectors had a maximum native prediction difference of
  2.7755575615628914e-17 across all seven models, within the 1e-12 tolerance.
- The six raw-result adapter cases differed by at most 2.8412206475124533e-18.
- Actual MediaPipe Tasks on the public portrait produced 478 face landmarks,
  52 blendshapes, 33 pose points, and 16 matrix entries. Against Python on the
  same image, normalized face coordinates differed by at most
  0.000839531421661377, blendshapes by 0.0042985230684280396, and matrix entries
  by 0.01866912841796875. Preselected bounds were 0.005, 0.02, and 0.1 respectively.
  These are cross-runtime landmark-output differences, separate from feature
  parity on identical inputs. A second public reference image produced one hand
  with 21 landmarks. Its maximum XYZ difference from Python was
  0.000884687528014183, within the preselected 0.005 bound.

The first MediaPipe package tested, 0.10.21, omitted x86_64 native libraries.
The final pinned 0.10.33 package includes x86_64 and ARM64 libraries aligned to
16 KB pages, and matches the Python tracking runtime version. The old package
is not used in the delivered APK. The app's native bridge also uses 16 KB alignment.
`flutter build apk --debug` completed successfully. Local emulator evidence is in
`.verification/device_*.json` and `.verification/android-instrumentation.log`.

The emulator camera preview also ran through the actual frame-processing pipeline.
Its generated scene contained no tracked person; the app showed unavailable
results and positioning guidance at about 12 processed FPS rather than zero
scores. Camera-service output confirmed that backgrounding closed the camera.
Screenshots are in `.verification/home.png` and `.verification/status.png`.
A real person's moving overlay alignment remains a physical-phone check.

## APKs and installation

All APKs are in `C:\Users\VINZ\Documents\calm-kaba\build\app\outputs\flutter-apk`:

| APK | Size | Device |
| --- | --- | --- |
| `app-arm64-v8a-debug.apk` | 113.6 MiB | ARM64 Android phones |
| `app-armeabi-v7a-debug.apk` | 89.0 MiB | Older 32-bit ARM phones |
| `app-debug.apk` | 220.9 MiB | Universal fallback |
| `app-x86_64-debug.apk` | 103.3 MiB | x86_64 emulator |

Copy the appropriate APK to the phone and open it from Files. Allow installation
from that file manager if Android requests it. Alternatively, enable USB debugging,
connect the phone, and run this from the app checkout:

```powershell
& "$env:LOCALAPPDATA/Android/sdk/platform-tools/adb.exe" install -r build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk
```

Open the installed app, tap Scan Now, allow Camera, and tap Scan Now again. The
existing launcher label is `thesis_anxiety`. Models and fonts are bundled; no
model download or server is needed. To regenerate the smaller APKs, use
`flutter build apk --debug --split-per-abi`.

`.verification/apks.json` contains APK SHA256 hashes, sizes, and native-library
inventories. Package inspection confirmed seven correct model assets and no
recorded parity inputs, Parquet files, or joblib bundles in the app APKs.

## Build again

Run from the app checkout in PowerShell:

```powershell
./tools/setup_native.ps1
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The native setup script fetches upstream LightGBM at commit
`8f7036f03627054d5a54a6f965b13f4b9ff2cb63` and its pinned dependencies. Downloaded
sources and research fixtures are git-ignored. Deployable native model files,
their schema/checksum manifests, and the public MediaPipe task bundles are
versioned, so building a clone does not need the participant dataset.

Regenerating exports or research parity fixtures is optional and requires the
local training run. Use `tools/export_pipeline.py --python-project <thesis_models>`
with that project's Python environment. The exporter only reads the research
directory. No participant records are copied into the application APK or Git.
Do not force-add ignored research inputs or verification files.

The Android build uses SDK 36, NDK 28.2.13676358, CMake 3.22.1, Java 17 bytecode,
CameraX 1.4.2, and MediaPipe Tasks Vision 0.10.33. Minimum Android version is 7.0
API 24. Native targets are arm64-v8a, armeabi-v7a, and x86_64. Gradle and native
compile concurrency are limited to two workers for this 16 GB machine.

For host JNI checks, build the same CMake project with MSVC and the Android Studio
JDK's JNI headers, then run `./gradlew.bat app:testDebugUnitTest` from `android/`.
The DLL must be at `.verification/native-host/Release/calm_lgbm.dll`. The CMake
project includes compatibility for the older MSVC runtime bundled with that JDK.

For Android instrumentation, first generate the public portrait reference:

```powershell
& '../thesis_models/.venv/Scripts/python.exe' tools/create_landmark_reference.py --python-project '../thesis_models'
cd android
./gradlew.bat app:assembleDebugAndroidTest
```

Install the app and test APKs on an emulator or test device, then run only
`com.example.thesis_anxiety.DevicePipelineTest` using AndroidJUnitRunner. This
reuses the recorded-window checks on Android and compares MediaPipe outputs on
the same public portrait and hand images with Python 0.10.33. The public image comes from
Google's MediaPipe test assets. It is unrelated to the participant dataset.

## Phone test checklist

1. Install the debug APK, open Calm Kaba, tap Scan Now, and allow Camera. Tap Scan
   Now again after the permission message.
2. Confirm the preview and moving face/body/hand landmarks align. Raise each hand
   separately, rotate the phone, and confirm restarting produces an aligned view.
3. Keep face, shoulders, hands, and knees visible as needed. Check unavailable
   guidance when anatomy leaves view and FPS warnings on slower hardware.
4. In Instant mode, wait at least five seconds. A valid threshold crossing should
   open the result page once and release the camera. Negative windows keep scanning.
5. In Continuous mode, check all seven results, stop, and open Your Log. A sustained
   detection should create one entry per symptom, with no entry every two seconds.
6. Open another tab, another page, or another app while scanning. Confirm the camera
   privacy indicator clears. Return and confirm scanning requires a fresh start.
7. Restart the app and confirm history persists. Check the interface with airplane
   mode enabled; model inference and bundled fonts work offline.

## Limits still requiring a physical phone

Live preview alignment, rotation/cropping across camera vendors, tracking under
real lighting, thermal/battery behavior, and sustained processed FPS need a real
phone. A static reference image cannot verify live temporal tracking or exposure.
The desktop adapter itself says parity with the original dataset exporter remains
unverified. This integration reproduces that adapter; it cannot establish the
original exporter's conventions or clinical validity. Behavioral model scores are
not anxiety severity or a diagnosis. Do not treat an unavailable result as zero.

The existing Kotlin 1.9.22 Gradle plugin produces a Flutter deprecation warning.
It does not block the verified Flutter 3.38.3 debug builds; a future Flutter upgrade
may require updating that plugin. No current build blocker remains.

## Upstream references

- [MediaPipe face landmarker for Android](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/android)
- [MediaPipe Java matrix output](https://github.com/google-ai-edge/mediapipe/blob/v0.10.33/mediapipe/tasks/java/com/google/mediapipe/tasks/vision/facelandmarker/FaceLandmarkerResult.java)
- [LightGBM 4.7.0](https://github.com/microsoft/LightGBM/tree/v4.7.0)
- Font licenses accompany the bundled Poppins and Open Sans files in `assets/fonts/`.
