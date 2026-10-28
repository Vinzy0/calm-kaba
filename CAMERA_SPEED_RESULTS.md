# Camera speed changes - 1.1.2+5

Branch: `codex/live-scores-and-tuning`, based on `83aa839` from `Vinzy0/calm-kaba`.
The user approved leaving MediaPipe rotation blocked and committing without GPG signing.

## Implemented and blocked work

1. **MediaPipe rotation is blocked.** At 90/270 degrees, converting landmarks back
   to upright coordinates did not meet the 0.005 XYZ tolerance. Face blendshapes
   also changed by up to 0.317262. See `ROTATION_PARITY.md`. No rotation fast path or
   switch is shipped; the existing crop/rotate path and upright adapter dimensions remain.
2. **RGBA memory reuse is implemented** in commit `4ce1a9c`. Packed RGBA planes
   (`pixelStride=4`, `rowStride=width*4`) copy into one mutable ARGB_8888 bitmap.
   Other layouts use CameraX `toBitmap()`. Its MPImage wrapper is retained because
   closing that wrapper recycles the bitmap. Resizing and stop/dispose release it
   on the analysis worker. Every submitted tracker reader is drained before the
   current image can be released/reused, including tracker failures and interruption.
3. **All four workers request Android DISPLAY priority (-4)** through one ThreadFactory:
   analysis, face, pose and hands. If Android rejects the priority request, the worker
   still runs at its existing priority and logs the reason instead of hanging startup.

The model assets, normalization, feature builders and classifier settings are unchanged.
Bitmap reuse removes the source bitmap allocation on eligible frames; the rotated
bitmap allocation remains because improvement 1 failed its preservation gate.

## Before/after measurements

Android 15, hardware-accelerated Pixel 6a-profile x86_64 emulator, 4 virtual CPU cores,
CPU delegates, v4 models, 640x480 RGBA -> 480x640 upright, full crop, rotation 270.
The **30 fps camera lock stayed on**, and Camera2 selected `[30, 30]`.
The emulated scene contained no tracked person; these are not phone/person measurements.

The native `CameraPanel` test harness uses the same 3:4 ViewPort and Developer
diagnostics producer as the app. It does not exercise the Flutter page's per-frame
packet handling/rebuild load. Each build ran twice, with 10 valid diagnostic packets
of warmup followed by 30 one-second packets per run. Builds were not running during
capture. Values below average the 60 diagnostic packets; stage values are means in ms.
Rolling stage/rate windows overlap, so these are descriptive timings, not independent
statistical trials or a production throughput guarantee.

| Developer diagnostic | Baseline `83aa839` | Bitmap reuse only | Reuse + priority |
| --- | ---: | ---: | ---: |
| YUV/RGBA -> bitmap (ms) | 0.768 | 0.352 | 0.307 |
| crop + rotate (ms) | 4.796 | 5.143 | 4.760 |
| trackers (wall) (ms) | 46.276 | 47.557 | 44.430 |
| analyzer total (ms) | 53.263 | 54.471 | 50.788 |
| processed fps | 18.031 | 17.522 | 18.835 |

| Build | Processed fps, run 1 | Processed fps, run 2 |
| --- | ---: | ---: |
| Baseline | 18.367 | 17.695 |
| Bitmap reuse | 17.088 | 17.956 |
| Reuse + priority | 19.538 | 18.133 |

Reuse consistently reduced conversion time by about 54%, but did not demonstrate an
overall fps improvement by itself. Priority reduced tracker wall time relative to
reuse-only in these runs. The combined average was about 4.5% above baseline, with
substantial run-to-run variation. **Sustained 20+ processed fps was not demonstrated.**
The remaining dominant stage is tracker wall time. Phone results remain outstanding.

Diagnostics confirmed `bitmapReuse=true`, `rowStride=2560` on the optimized builds,
and `workerPriority=-4` on the priority build. Capture fps is separate from processed
fps: requesting a 30 fps exposure range does not force MediaPipe to process 30 fps.

## Validation

* `flutter analyze`: passed, no issues.
* `flutter test`: all 5 passed.
* `app:testDebugUnitTest`: 6 ran, 2 passed, 4 failed because ignored research fixtures
  are absent: `adapter_pixel.json`, `windows.json`, `windows_v6.json`, `predictions.json`.
  The original rolling-window/tracking test and the new reader-drain test passed.
  The host JNI library was built locally; missing fixtures were not fabricated or skipped.
* Android instrumentation: 4 passed. Two check exact CameraX pixel agreement, channel
  and row layout, buffer/wrapper identity, padded-stride fallback, resize and cleanup;
  one checks real Android priorities on all four worker types; one reproduces the
  known rotation incompatibility. That last test is **not** an equivalence pass.
* Six camera benchmark runs completed, each collecting 30 post-warmup diagnostics packets.
* Review traced image ownership and the start/stop/dispose queues for one live camera
  session with three concurrent tracker readers. The original crop/rotate and adapter
  calls still receive the same upright bitmap and dimensions.
* Release build passed for arm64 and x86_64. APK inspection confirmed arm64-only native
  libraries, versionName `1.1.2`, and ABI-specific Android versionCode `2005` for the
  delivered arm64 APK (Flutter version `1.1.2+5`).
* The actual x86_64 release Flutter app opened, ran Continuous Scan, displayed Developer
  diagnostics, and restarted a scan after background/return. No CalmCamera/AndroidRuntime
  errors were observed. Two separate post-warmup 30-packet UI smoke samples showed
  strong rendering/load sensitivity; these are final-build samples, not additional
  before/after comparisons. The emulated scene still had no tracked anatomy.

| Actual release app view | Convert ms | Crop/rotate ms | Tracker wall ms | Analyzer total ms | Processed fps |
| --- | ---: | ---: | ---: | ---: | ---: |
| Diagnostics visible, preview scrolled offscreen | 0.258 | 4.589 | 44.770 | 49.907 | 19.509 |
| Preview visible after background/return and restart | 0.387 | 9.418 | 69.485 | 79.733 | 12.092 |

The preview-visible result reinforces that the 20 fps goal remains unmet in this
emulator. The native harness isolates pipeline work and must not be presented as
end-to-end app throughput. A phone comparison is still required.

## Test on a phone

Copy the arm64 release APK to the phone and open it from Files to install. Start
the app, allow Camera if requested, and tap Scan Now again after permission is granted.

For every comparison use **Continuous Scan**, **Developer diagnostics on**, GPU off,
v4/all-landmark toggle off, and **Lock camera at 30 fps on**. Use the same lighting,
camera, distance and orientation, with face, hands and knees visible. Warm up for
10 seconds, then capture/copy diagnostics over two minutes; repeat the run. Use the
five table rows above, plus tracking rates and heat. Repeat for ten minutes to check
thermal behavior. Avoid comparing peak fps from a single packet.

* **Memory reuse:** INPUT should show `bitmapReuse=true` when `rowStride=width*4`.
  If it is false, that phone is using the safe CameraX fallback. Check conversion
  timing, Stop/Start, background/return, and rotation/restart for corrupted colors,
  stale overlays or recycled-bitmap errors. For an isolated comparison, compare
  `4ce1a9c` with `83aa839` using identically built APKs.
* **Thread priority:** INPUT should show `workerPriority=-4`. Compare tracker wall,
  analyzer total and processed fps against memory-only commit `4ce1a9c`. Check preview
  and button responsiveness as well. Priority 0 plus a CalmCamera warning means the
  phone rejected the request; scanning continues using its existing priority.
* **MediaPipe rotation:** remains unavailable, as approved. There is no switch to test.

The APK enables memory reuse and priority automatically. There are no new toggles
for these two changes. To build the isolated memory/baseline APKs without changing
this checkout, create separate detached checkouts under `CalmKabaDev`:

```powershell
. ..\dev-shell.ps1
git worktree add --detach ..\calm-kaba-perf-baseline 83aa839
git worktree add --detach ..\calm-kaba-perf-reuse 4ce1a9c
```

From each new checkout, run `. ..\dev-shell.ps1`, `./tools/setup_native.ps1`, then
`flutter build apk --release --target-platform android-arm64 --split-per-abi`.
Install its `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, run the phone
comparison, then reinstall 1.1.2+5. These isolated builds have not been built for arm64
in this run; only the final arm64 release is a delivered build.
