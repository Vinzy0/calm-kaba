# MediaPipe rotation: blocked

The proposed `ImageProcessingOptions.rotationDegrees` fast path is **not enabled**.
The user approved keeping it blocked after the reference comparison failed the
0.005 landmark tolerance and changed blendshapes and the facial transform matrix.
`CameraPanel` retains its existing crop/rotate bitmap path, upright dimensions,
landmark adapter and model inputs. There is no rotation switch to enable an unsafe path.

## Reference experiment (2026-10-28)

Android 15 x86_64 emulator, MediaPipe Tasks 0.10.33, CPU. The official MediaPipe
`portrait.jpg` and `thumb_up.jpg` test images were rotated into sensor orientation.
Fresh VIDEO tasks compared the existing bitmap rotation with the unrotated bitmap
and MediaPipe rotation options at 90 and 270 degrees. All face, pose and hand
comparisons contained detected landmarks; empty results could not pass.

MediaPipe returns coordinates in the original input frame. The experiment mapped
XY clockwise into the upright frame and scaled normalized Z by sensor width /
upright width before comparing. The table shows maximum absolute errors.

| Output | 90 degrees | 270 degrees |
| --- | ---: | ---: |
| Face XY (478 points) | 0.002301 | 0.002673 |
| Face XYZ | 0.028590 | 0.028386 |
| Pose XYZ (33 points, partial-body portrait) | 1.052752 | 1.762099 |
| Hand XYZ (21 points) | 0.005909 | 0.003919 |
| Face blendshapes | 0.214672 | 0.317262 |
| Face matrix entries, before any matrix conversion | 22.820457 | 22.165356 |

The partial-body portrait is not a full-body pose accuracy fixture. Independently
of its unstable pose points, the face blendshape change prevents using the proposed
path with the current classifiers. Rotating overlay coordinates cannot repair
blendshape coefficients. No tolerance was relaxed and no model was changed.

`RotationParityTest.currentMediaPipeRotationChangesModelInputs` now **passes when
it reproduces this incompatibility**. It is not an equivalence certification.
Its report is written to the target app's `files/rotation_parity.json`.

## Reproduce

The public reference images are ignored test assets, never part of the app APK:

```powershell
. ..\dev-shell.ps1
New-Item -ItemType Directory -Force android/app/src/test/resources/parity | Out-Null
Invoke-WebRequest https://storage.googleapis.com/mediapipe-assets/portrait.jpg -OutFile android/app/src/test/resources/parity/portrait.jpg
Invoke-WebRequest https://storage.googleapis.com/mediapipe-assets/thumb_up.jpg -OutFile android/app/src/test/resources/parity/thumb_up.jpg
```

Build/install the debug app and `app:assembleDebugAndroidTest` test APK on the same
device, then run:

```powershell
adb shell am instrument -w -r -e class com.example.thesis_anxiety.RotationParityTest com.example.thesis_anxiety.test/androidx.test.runner.AndroidJUnitRunner
adb shell run-as com.example.thesis_anxiety cat files/rotation_parity.json
```

A future implementation must pass the original 0.005 preservation gate, preserve
blendshape/matrix features, retain upright adapter dimensions, and keep the bitmap
fallback for non-full crops before the requested default-off switch is added.
