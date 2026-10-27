# Restricted vs-control Android variant

Branch: `codex/restricted-vs-control`.

This checkout contains the restricted variant of the original camera integration.
Both variants are committed to the user's private personal repository, separate
from the team's original repository. The full-feature model assets remain intact
on their own branch. No model retraining or participant-data upload is part of
this change. The finished install APK is also in the user's private Google Drive.

## Models and inputs

All seven classifiers run on each completed four-second window. They use the
51-participant run `2026-10-27_51participants_full_vs_restricted`, feature version
`restricted`, comparison mode `vs_control`, and their saved thresholds of 0.5.

| Classifier | Prediction inputs | Feature count |
| --- | --- | ---: |
| Fidgeting | Hands, wrists, elbows, shoulders and torso movement | 373 |
| Hand tremor | Hands, selected finger points and hand openness | 222 |
| Knee tremor | Hips, knees and ankles | 121 |
| Avoidant gaze | Iris/eye geometry, head orientation and eye-look expressions | 103 |
| Facial tension | Mouth, brow, jaw, cheek, nose and eye-squint expression features | 158 |
| Heavy breathing | Shoulders and torso endpoints and dimensions | 111 |
| Fear | Selected facial geometry, expressions and head orientation | 213 |

Each list includes only its allowed detection flags. The exporter checks the
ordered feature names against the feature rules declared before training. The
Android loader checks model identity, unique symptoms, feature counts, schema
membership and native model checksums. Inference selects the exact ordered subset
for each classifier before calling LightGBM. A hand-tremor classifier receives 222
values, not the entire shared feature vector.

Normalization may still use shared reference landmarks. For example, hand
coordinates use shoulders and hips as a reference and pose wrists for assigning
left and right hands. These reference landmarks do not become hand-tremor
classifier inputs.

## Performance scope

The shared feature union is **788**, compared with **822** in the full-feature
variant. The extractor skips unused signal statistics and emits only that union.
It computes shared features once, not separately for each classifier.

Running all seven still requires the face, pose and hand MediaPipe Tasks. Those
neural networks have fixed landmark outputs: selecting fewer classifier inputs
does not shrink their internal outputs or eliminate those three tracking passes.
No GPU/delegate change or lower sampling threshold is introduced here. Phone FPS
must be measured rather than inferred from the smaller per-model feature lists.

This deliverable uses a release APK to remove Flutter debug overhead. Comparing
its FPS to the earlier debug APK changes both model selection and build mode.
Use the same build mode on both variants to isolate the model-selection effect.

## Behavior and history

Instant mode opens the highest-scoring above-threshold result in the first valid
positive window. Continuous mode displays all seven results and logs sustained
episodes with the existing cooldown. All camera lifecycle and quality gates stay
in effect, including no scores below 8 processed FPS and tremor warnings below 20.

History obtains the model identity from each native result. New entries identify
`restricted/vs_control`; older entries remain readable. This variant uses a separate
Android application ID, `com.example.thesis_anxiety.restrictedcontrol`, so it can
be installed next to the existing app and has a separate history.

These models were trained to distinguish each symptom from control, not from the
other six symptom categories. Several classifiers can fire on one window. This
branch does not turn them into an eight-class classifier or guarantee rejection
of other symptoms.

## Build and test

From this checkout:

```powershell
./tools/setup_native.ps1
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
cd android
./gradlew.bat app:testDebugUnitTest
cd ..
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

The deployable model and tracking assets are versioned, so building a clone does
not need the participant dataset. Regenerating exports or research fixtures is
optional and needs the local training run. Use `tools/export_pipeline.py
--python-project <thesis_models>` with that project's Python environment.

The exporter creates native LightGBM text models without a classifier conversion.
It compares each export against its Python bundle on all 16,057 feature windows
and 32 missing-value cases per model. Recorded fixtures remain ignored and are
not included in the application APK.

Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` on the Xiaomi 14T.
Its launcher label is **Calm Kaba Control**. It is signed with the existing local
debug key for testing, despite using release compilation.

The verified ARM64 release APK is 53,104,476 bytes. Its SHA256 is
`f1804ee45b9689bc0f09bc633e888405d3658d746ed41374098a881819667a2c`.
It contains exactly the seven restricted / vs_control manifests and native text
models, an ARM64 native bridge, and no recorded parity inputs, Parquet files or
joblib bundles.

[Private Google Drive APK](https://drive.google.com/file/d/1hl5Vhm91x7fgLSycm97avSuznzHDyqzV/view?usp=drivesdk).
Open this while signed into the connected Google account, download the file and
open it on the phone to install.

Open it, select Continuous Scan, tap Scan Now, grant Camera, then tap Scan Now
again. Check all seven results, processed FPS and history. Test Instant Scan,
rotation and backgrounding. The expected settling/first-window delay is about
five seconds. Live phone tracking alignment and FPS still require that phone.

## Verification results

Flutter analysis reported no issues. All five Flutter tests, five JVM tests and
both Android instrumentation tests passed. The variant also cold-launched
successfully on the x86_64 emulator.

| Check | Result |
| --- | --- |
| Seven exported models against Python, all 16,057 windows and 32 missing cases per model | Exact probabilities |
| Host Kotlin features, 24 recorded windows | 17,788 finite values exact; all 1,124 missing values matched |
| Host recorded-window and 144-vector JNI predictions | Exact probabilities |
| Android Kotlin features, same 24 windows | Exact finite values and missing-value mask |
| Android end-to-end recorded-window predictions | Maximum difference 8.67e-19 |
| Android JNI, 144 additional vectors for all seven models | Maximum difference 2.22e-16, below 1e-12 tolerance |
| Android face, pose and hand reference images | Required outputs and existing cross-runtime bounds passed |
| Original app checkout | All 129 copied source-file hashes unchanged |
| APK inspection | Seven correct models, ARM64 bridge, no research fixtures |

The first existing emulator lacked installation storage. A fresh isolated emulator
was used for the passing Android tests instead of deleting existing emulator data.
Verification evidence is saved in `.verification/verification_summary.json` and
the other `.verification/` reports. These checks establish software parity, not
phone FPS or live landmark accuracy. The original dataset-exporter normalization
compatibility limitation from the first integration still applies.
