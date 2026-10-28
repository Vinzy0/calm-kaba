"""Generate Kotlin parity fixtures for pixel-space normalization and v6 (1,122) features.

Reference implementations are the lead's own code, imported unchanged:
  * extractors/allextractor.py face_features / pose_features / hand_features (dataset exporter)
  * train/27-10-26 train/common.py (feature builder), via the run's provenance snapshot
Outputs go to android/app/src/test/resources/parity/ (git-ignored research fixtures).

Run with the thesis_models venv:
  python -I tools/make_v6_fixtures.py --lead <anxiety_detection_prototype> --run <v6 run dir>
"""
import argparse, importlib.util, itertools, json, math, sys, warnings
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pandas as pd

APP = Path(__file__).resolve().parents[1]
FIX = APP / "android/app/src/test/resources/parity"
SYMPTOMS = ["fidgeting", "hand_tremor", "knee_tremor", "avoidant_gaze", "facial_tension", "heavy_breathing", "fear"]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod


def clean(v):
    return None if v is None or (isinstance(v, float) and not math.isfinite(v)) else float(v)


def adapter_cases(X):
    """Raw MediaPipe-like points -> exporter rows at several frame sizes."""
    cases = json.loads((FIX / "adapter.json").read_text())
    out = []
    for c in cases:
        for (w, h) in [(480, 640), (1280, 720), (720, 720)]:
            lm = lambda p: SimpleNamespace(x=p[0], y=p[1], z=p[2], visibility=p[3], presence=p[4])
            face = [lm(p) for p in c["face"]] or None
            pose = [lm(p) for p in c["pose"]] or None
            hands = [[lm(p) for p in hh] for hh in c["hands"]]
            row = {}
            row.update(X.face_features(face, w, h))
            pdata, transform = X.pose_features(pose, w, h)
            row.update(pdata)
            # App rule (matches dataset 97%): assign hands to anatomical pose wrists by image distance.
            left = right = None
            if pose and hands:
                wr = [(pose[15].x * w, pose[15].y * h), (pose[16].x * w, pose[16].y * h)]
                hs = hands[:2]
                slots = min(itertools.permutations(range(2), len(hs)),
                            key=lambda o: sum(math.hypot(hh[0].x * w - wr[s][0], hh[0].y * h - wr[s][1]) for hh, s in zip(hs, o)))
                for hh, s in zip(hs, slots):
                    if s == 0: left = hh
                    else: right = hh
            row.update(X.hand_features(left, "left_hand", w, h, transform))
            row.update(X.hand_features(right, "right_hand", w, h, transform))
            keep = {k: clean(v) if v != "" else None for k, v in row.items() if k.endswith(("_x", "_y")) or k.endswith("_visibility")}
            out.append(dict(name=f"{c['name']}_{w}x{h}", width=w, height=h, face=c["face"], pose=c["pose"], hands=c["hands"],
                            blend=c["blend"], packed_matrix=c["packed_matrix"], row=keep))
    (FIX / "adapter_pixel.json").write_text(json.dumps(out))
    print("adapter cases", len(out))


def window_cases(C, run, lead):
    rows = pd.read_parquet(run / "parity_rows.parquet")
    feats = pd.read_parquet(run / "features_v6.parquet")
    info = json.loads((run / "feature_info.json").read_text())
    names = info["v6_names"]; bs, fm = info["blendshapes"], info["face_matrix"]
    cols = list(dict.fromkeys(C.FLAGS + sum(C.PART_COLS.values(), []) + C.VIS_COLS + bs + fm))
    import joblib
    warnings.filterwarnings("ignore")
    models = [joblib.load(lead / f"models/27-10-26 trained/light/{s}/model.joblib") for s in SYMPTOMS]
    cases = []
    for vid, v in rows.groupby("video_id", sort=False):
        v = v.sort_values("frame").reset_index(drop=True)
        ts = pd.to_numeric(v["timestamp_ms"]).to_numpy(np.float64); t = (ts - ts[0]) / 1000
        f = feats[feats.video_id.astype(str) == str(vid)].reset_index(drop=True)
        for k in list(range(0, len(f), max(1, len(f) // 4)))[:4]:
            start = float(f.win_start_s[k])
            lo, hi = np.searchsorted(t, [start - 0.2, start + 4.2])
            V = v.iloc[lo:hi]
            vals = np.column_stack([pd.to_numeric(V[c], errors="coerce").to_numpy(np.float64) for c in cols])
            x = f.loc[k, names].to_numpy(np.float64)
            probs = [float(m["model"].predict_proba(x[None].astype(np.float32))[0, 1]) for m in models]
            cases.append(dict(name=f"{v.symptom.iloc[0]}_{k}", start=start, times=t[lo:hi].tolist(), columns=cols,
                              rows=[[clean(a) for a in r] for r in vals], features=[clean(a) for a in x], probabilities=probs))
    (FIX / "windows_v6.json").write_text(json.dumps(cases))
    print("window cases", len(cases))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lead", type=Path, required=True)
    ap.add_argument("--run", type=Path, required=True)
    ap.add_argument("--adapter-only", action="store_true")
    a = ap.parse_args()
    X = load(a.lead / "extractors/allextractor.py", "allextractor")
    C = load(a.run / "provenance/common.py", "lead_common")
    adapter_cases(X)
    if not a.adapter_only:
        window_cases(C, a.run, a.lead)


if __name__ == "__main__":
    main()
