# Restricted vs-control Android variant

Branch: `codex/restricted-vs-control`.

This checkout contains the restricted variant of the original camera integration.
Both variants are committed to the user's private personal repository, separate
from the team's original repository. The full-feature model assets remain intact
on their own branch. No model retraining or participant-data upload is part of
this change.

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

Use version **1.0.1+2 or newer**. The original 1.0.0 release APK (SHA256
`f1804ee45b9689bc0f09bc633e888405d3658d746ed41374098a881819667a2c`)
has a camera-startup bug and should not be distributed. Its old Drive upload is
also obsolete. The earlier numerical parity tests used debug Android builds and
did not establish release camera startup.

The release optimizer removed MediaPipe protobuf fields used through reflection,
causing `Field platform_ ... not found` before CameraX could bind. The application
now includes the Protobuf Java Lite maintainers' recommended keep rule in
`android/app/proguard-rules.pro`. It also preserves MediaPipe's native packet
callbacks and Flogger's stack-inspecting factory and caller-finder helpers. Without
the latter, R8 inlining causes `Graph` initialization to fail with "no caller
found on the stack" after the protobuf issue is fixed. Camera failures now log
their complete exception chain under the `CalmCamera` tag and show the underlying
cause in the UI. R8 and release optimization remain enabled.
The same fix is present on the full-feature branch. The version increment allows
installing the corrected APK over the old variant using the same signing key.

The corrected ARM64 APK is 53,366,620 bytes, version 1.0.1 (versionCode 2002).
SHA256: `83fb9d65be2f9adc84db9afd8d56d8068b33949fc47fca4599701580b3054389`.
It contains the unchanged seven restricted/control models and three tracking
assets; all 12 deployment assets match this branch byte for byte. No parity
fixtures or research bundles are packaged. Its signing certificate matches the
previous APK.

Release validation uses a non-debuggable, R8-optimized x86_64 APK with identical
Java DEX bytes to the ARM64 APK. The isolated Android emulator opened its front
camera, processed continuous video for over 50 seconds and displayed all seven
quality-gated result rows without startup errors. Its synthetic camera scene has
no real person, so those rows correctly report unavailable tracking. This checks
release startup and frame processing, not physical-phone accuracy or FPS. The
Infinix Note 12 still needs a phone retest with this updated APK.
Backgrounding released the camera, and resuming then starting a fresh scan opened
it again. The `CalmCamera` error log remained empty. Local evidence is in
`.verification/release_camera_apk_check.json`, the camera service dumps and
`.verification/release_fixed_continuous.png`.

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
