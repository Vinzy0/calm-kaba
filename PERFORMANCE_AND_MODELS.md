# Performance, tracking and model study (2026-10-28)

Original study: version 1.1.0+3. Emulator results only; physical-phone measurements are still outstanding.

Camera follow-up, version 1.1.2+5: [camera speed results and phone checklist](CAMERA_SPEED_RESULTS.md).
RGBA bitmap reuse and higher worker priority are implemented. MediaPipe rotation
remains blocked after its landmark/feature preservation check failed; see
[rotation comparison](ROTATION_PARITY.md). Sustained 20+ processed fps has not been demonstrated.

## Branches (Vinzy0/calm-kaba)

| Branch | Based on | Change | Status |
| --- | --- | --- | --- |
| `codex/camera-behavior-integration` | – | Previous known-working app (1.0.1+2) | Preserved |
| `codex/restricted-vs-control` | – | Restricted models | Preserved |
| `codex/live-diagnostics` | camera-behavior-integration | Developer diagnostics (baseline for all comparisons) | Kept |
| `codex/pixel-normalization` | live-diagnostics | Landmark normalization in pixel space, as the dataset exporter does | Kept (bug fix) |
| `codex/parallel-tracking` | live-diagnostics | Face/pose/hand tasks run concurrently | Kept |
| `codex/mediapipe-gpu` | parallel-tracking | Optional GPU delegate with per-task CPU fallback | Kept as a developer option, default CPU |
| `codex/all-landmark-models` | pixel-normalization | The lead's 1,122-feature LightGBM models (v6) | Kept as a developer option |
| `codex/ui-update` | camera-behavior-integration | Kyrie's `content-updates` merged | Kept |
| `codex/integration-tested` | all-landmark-models | All of the above + GPU fallback fix | Release candidate |

## Diagnostics

Turn on **Developer diagnostics** under the camera card. It shows camera capture fps (Camera2 callback), estimated preview fps (Flutter frames), analyzer, processed-landmark and prediction rates, an estimate of dropped frames, and per-stage mean/p50/p95/max timings. Stages: conversion, crop and rotate, face, pose, hands, tracker wall time, adapt and window, window features, 7 classifiers, and total. Ages use the sensor clock: capture → analyzer, capture → result, overlay age at draw, and window end → prediction. Also shown: tracking rates, input resolution, the requested vs running delegate with any fallback reason, the active model bundle, and the AE fps range and exposure. Packets go out at 1 Hz and are also logged as `CalmDiag` (`adb logcat -s CalmDiag`).

## Measured on the emulator (Pixel 6a AVD, x86_64, release, 640x480 → 480x640 portrait, CPU)

There is no person in the emulator scene, so palm and pose detection run without landmark tracking. Phone numbers will differ.

| Build | Processed fps | Analyzer mean | Overlay age mean |
| --- | --- | --- | --- |
| Baseline (diagnostics only), runs 1 / 2 | 22.1 / 19.8 | 41.5 / 47.2 ms | 42 / 67 ms |
| Integrated (parallel tracking), runs 1 / 2 | 29.2 / 23.3 | 28.7 / 38.8 ms | 19 / 54 ms |

Measured bottleneck: the three trackers ran one after another (pose ≈ 15 ms + hands ≈ 15 ms + face ≈ 5 ms). Run concurrently, the wall time is close to the slowest task, though each task gets slower under contention. Crop and rotate takes ≈ 5–9 ms. Window features take ≈ 5 ms and the seven classifiers ≈ 0.1 ms, every 2 s. Classifier inference is **not** a bottleneck, so changing classifiers would not raise fps.

GPU: on the emulator the GPU tasks are created but fail at inference (`GL_INVALID_ENUM`). Each one is replaced by a CPU task on the same thread, scanning continues at 29 fps, and diagnostics show the reason. Real GPU speed and CPU/GPU numerical agreement (test `gpuDelegateMatchesCpuOnReferenceImage`) need a phone.

## Training-to-app audit

* **Fixed:** `allextractor.py` normalizes in pixels (x·W, y·H) and scales the body by max(shoulder width, 0.25·torso, 1 px). The app (and `webcam_core.py`) normalized 0–1 coordinates on a 3:4 crop. On the public portrait the old app values differed from the exporter by up to 0.175 face units. They now match the exporter's own functions within 5e-8 across 1,032 values at 3 frame sizes.
* Hand assignment by pose wrists matches the dataset's left/right labels in 97% of frames.
* 25% of clips were recorded at 20 fps and the rest at 30 fps; windows resample to 30 Hz.
* `f_pose_shoulder_width_*` spectral features (and the pooled face-eye groups containing 133/362) come from signals that are constant by construction. They are rounding noise and cannot be reproduced live.

## All-landmark models (lead, v6)

The 822 v4 features are followed by 300 pooled features. All seven models use the same 1,122-column schema, 400 trees each. Through the pooled groups, every model uses features that reach all 553 landmarks; individually only the original 40 points appear. Kotlin vs the lead's builder on 16 recorded windows: 15,612 finite features (3,890 pooled) identical, NaN masks identical, and 0 probability difference from his joblib models. The lead's `main.py` still uses the older detectors, not these bundles.

## Fair model comparison (thesis_models/training_runs/2026-10-28_v6_all_landmark)

Development: 41 participants, 5 participant folds, inner-validation participants used for thresholds and tuning. Final: 10 held-out participants, evaluated once (plan in `results/preregistered_final.md`).

| Holdout macro F1 | v4 822 | v6 1,122 |
| --- | --- | --- |
| Symptom vs everything, threshold 0.5 | 0.484 | 0.485 |
| Symptom vs everything, inner-validation thresholds | 0.467 | 0.462 |
| Symptom vs control, threshold 0.5 | 0.824 | 0.828 |

Vs-control models fire on 30–67% of the *other* symptoms' windows (control false-positive rate 10–41%), so the two task definitions are not interchangeable. LightGBM grid tuning and the leg-frame knee features gave no development gain and were not used. Per-symptom thresholds did not generalize. **Default stays the 822-feature vs-everything bundle**; v6 is selectable in developer mode. Per-symptom precision, recall, F1, confusion counts, fold spread and cross-activations are in `results/*_summary.csv` and `*_folds.csv`. Each model is 400 trees (≈ 0.8 MB of text), and all seven together take ≈ 0.1 ms per window on the emulator.

The lead's recorded CNN / MLP / LightGBM out-of-fold macro F1 (his folds, vs control) is 0.774 / 0.770 / 0.801.

## Knee tremor

* Leg landmarks barely separate knee-tremor from control clips in any frame (body-normalized, leg-local re-normalized, knee angle, depth): best clip AUC 0.56. Re-normalizing does not recover the motion, so hip subtraction is not the main cause.
* The lead's knee model takes 55% of its gain from hand features, 22% from face and 8% from legs. It probably relies on hands resting on the knees or other co-occurring behaviour.
* Sampling rate matters most: with models trained at 30 fps, knee F1 is 0.761 at 30 fps, 0.711 at 15, 0.624 at 10 and 0.489 at 7.5 (hand tremor 0.809 → 0.781). The phones' previous 5–9 processed fps is enough by itself to break knee tremor.
* Pose Lite reports knee visibility ≥ 0.5 in ≈ 100% of frames, so visibility can't confirm that the legs are really tracked. The original videos are not on this machine, so re-extraction with a heavier pose model could not be tested.

## Tracker alternatives

ML Kit Face Mesh (beta) gives 468 points with no iris, blendshapes or transform matrix. ML Kit Pose gives 33 BlazePose points, and there is no ML Kit hand-landmark API. The current models need iris (468/473), 52 blendshapes, the 4x4 matrix and 21-point hands, so ML Kit would require new features and retraining. It was not implemented.

## APKs (`C:\Users\VINZ\Documents\calm-kaba-apks`)

* `calm-kaba-1.1.0+3-integrated-arm64-v8a-release.apk` – Xiaomi 14T, Infinix Note 12, most phones
* `calm-kaba-1.1.0+3-integrated-armeabi-v7a-release.apk` – older 32-bit phones
* `calm-kaba-1.1.0+3-integrated-x86_64-release.apk` – emulator
* `calm-kaba-diagnostics-baseline-x86_64-release.apk` – baseline for comparison
* Known-working fallback: the 1.0.1+2 APK in `calm-kaba-restricted-control/build/app/outputs/flutter-apk/`

Phone test: install, open, scroll to **Developer diagnostics** and turn it on, tap Scan Now and allow Camera, then tap Scan Now again. Sit with face, hands and knees visible for 2 minutes and screenshot the panel. Repeat for 10 minutes to check heating. Then turn on GPU delegate, stop and start a scan, and screenshot again. Also check Stop/Start, Home and return, rotation, Instant and Continuous modes, and Your Log.
