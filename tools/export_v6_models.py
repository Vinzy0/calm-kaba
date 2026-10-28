"""Export the lead's seven LightGBM vs-control bundles (1,122 features) for the app.

Reads models/27-10-26 trained/light/<symptom>/model.joblib from the lead's repository,
writes the unchanged trees with booster_.save_model, and records each schema, threshold
and checksum. Output: android/app/src/main/assets/behavior_v6/. The original 822-feature
models in assets/behavior/ are untouched.
"""
import argparse, hashlib, json, subprocess, warnings
from pathlib import Path

import joblib
import numpy as np

APP = Path(__file__).resolve().parents[1]
OUT = APP / "android/app/src/main/assets/behavior_v6"
SYMPTOMS = ["fidgeting", "hand_tremor", "knee_tremor", "avoidant_gaze", "facial_tension", "heavy_breathing", "fear"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lead", type=Path, required=True)
    ap.add_argument("--run", type=Path, required=True, help="v6 run directory with feature_info.json")
    a = ap.parse_args()
    warnings.filterwarnings("ignore")
    OUT.mkdir(parents=True, exist_ok=True)
    info = json.loads((a.run / "feature_info.json").read_text())
    commit = subprocess.run(["git", "-C", str(a.lead), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    models = []
    ref = None
    for s in SYMPTOMS:
        src = a.lead / f"models/27-10-26 trained/light/{s}/model.joblib"
        b = joblib.load(src)
        assert b["symptom"] == s and b["feature_set"] == "both" and len(b["features"]) == 1122
        assert b["features"] == info["v6_names"], "lead schema differs from rebuilt v6 feature order"
        ref = ref or b["features"]; assert b["features"] == ref
        text = b["model"].booster_.model_to_string()
        (OUT / f"{s}.txt").write_bytes(text.encode("utf-8"))  # LF only; LightGBM rejects CRLF
        imp = b["model"].booster_.feature_importance("split")
        models.append(dict(symptom=s, file=f"{s}.txt", threshold=float(b["threshold"]), features=b["features"],
                           model_sha256=hashlib.sha256(text.encode()).hexdigest(),
                           source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),
                           trees=b["model"].booster_.num_trees(), used_features=int((imp > 0).sum()),
                           used_pooled=int(sum(1 for n, i in zip(b["features"], imp) if i > 0 and n.startswith("p_")))))
    manifest = dict(run_id="lead_2026-10-27_lgbm_vs_control_both", feature_version="v6", mode="vs_control",
                    source_repo="Vinzy0/anxiety_detection_prototype", source_commit=commit, window=info["window"],
                    bs_names=info["blendshapes"], fm_names=info["face_matrix"], models=models,
                    note="Trees unchanged from the lead's joblib bundles; trained on all 51 participants (symptom vs control).")
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))
    print(json.dumps([{k: m[k] for k in ("symptom", "trees", "used_features", "used_pooled")} for m in models]))


if __name__ == "__main__":
    main()
