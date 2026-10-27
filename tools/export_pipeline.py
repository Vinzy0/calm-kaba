"""Export only the requested seven bundles. Run with thesis_models' Python env.

No training, network calls, or changes to the source research directory.
Deployable assets are versioned in the personal app copy; research fixtures stay local.
"""
import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd
import pyarrow.parquet as pq

APP = Path(__file__).resolve().parents[1]
RUN_ID = '2026-10-27_51participants_full_vs_restricted'
FEATURE_VERSION = 'restricted'
MODE = 'vs_control'


def clean(value):
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, np.ndarray)):
        return [clean(v) for v in value]
    if isinstance(value, (float, np.floating)):
        return float(value) if np.isfinite(value) else None
    if isinstance(value, np.integer):
        return int(value)
    return value


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(clean(data), separators=(',', ':'), allow_nan=False), encoding='utf-8')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--python-project', type=Path, required=True)
    args = ap.parse_args()
    root = args.python_project.resolve()
    sys.path.insert(0, str(root))
    import common as c
    import webcam_core as w
    from train_comparison import predict_bundle

    run = root / 'training_runs' / RUN_ID
    assets = APP / 'android/app/src/main/assets'
    target = assets / 'behavior'
    target.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((run / 'manifest.json').read_text())
    rules = json.loads((run / 'feature_rules.json').read_text())['restricted']
    table = pd.read_parquet(run / 'features.parquet')
    models = []
    max_error = 0.0
    for symptom in c.SYMPTOMS:
        source = run / 'models' / FEATURE_VERSION / f'{symptom}_{MODE}.joblib'
        b = joblib.load(source)
        assert (b['run_id'], b['feature_version'], b['mode'], b['symptom']) == (RUN_ID, FEATURE_VERSION, MODE, symptom)
        assert b['features'] == rules[symptom]['features']
        assert b['window'] == c.WINDOW and b['bands'] == c.BANDS
        assert b['dataset_sha256'] == manifest['source_sha256']
        assert b['preprocessing']['common_sha256'] == hashlib.sha256((root/'common.py').read_bytes()).hexdigest()
        b['model'].set_params(n_jobs=1)
        path = target / f'{symptom}.txt'
        b['model'].booster_.save_model(str(path))
        exported = lgb.Booster(model_file=str(path))
        x = table.loc[:, b['features']]
        original = predict_bundle(b, table)
        reloaded = exported.predict(x, num_threads=1)
        error = float(np.max(np.abs(original - reloaded)))
        assert error <= 1e-12
        # Explicit missing-input cases, independently of the real dataset.
        missing = x.iloc[:32].copy()
        missing.iloc[::2, ::3] = np.nan
        missing.iloc[-1, :] = np.nan
        error = max(error, float(np.max(np.abs(predict_bundle(b, missing) - exported.predict(missing, num_threads=1)))))
        assert error <= 1e-12
        max_error = max(max_error, error)
        models.append(dict(symptom=symptom, file=path.name, features=b['features'], threshold=b['threshold'],
                           feature_rationale=rules[symptom]['rationale'],
                           bundle_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                           model_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))

    features = list(dict.fromkeys(f for model in models for f in model['features']))
    bs = list(dict.fromkeys(re.sub(r'_(mean|std|max)$', '', f[2:]) for f in features if f.startswith('f_bs_')))
    fm = list(dict.fromkeys(re.sub(r'_(mean|std)$', '', f[2:]) for f in features if f.startswith('f_face_matrix_')))
    signals, _ = c.compute_signals({n: np.zeros(1) for n in c.landmark_cols()})
    extracted_features = c.feature_names(signals, bs, fm)
    assert set(features) <= set(extracted_features)
    indices = {name: i for i, name in enumerate(features)}
    model_indices = [[indices[f] for f in model['features']] for model in models]
    write(target/'manifest.json', dict(run_id=RUN_ID, feature_version=FEATURE_VERSION, mode=MODE,
        lightgbm_version=lgb.__version__, adapter=w.ADAPTER, window=c.WINDOW, bands=c.BANDS,
        bs_names=bs, fm_names=fm, features=features, models=models, source_sha256=manifest['source_sha256']))
    tracking = {}
    for name, sha in w.ASSET_SHA256.items():
        source = root/'tracking_assets'/name
        assert hashlib.sha256(source.read_bytes()).hexdigest() == sha
        dest = assets/'tracking'/name
        dest.parent.mkdir(exist_ok=True)
        shutil.copyfile(source, dest)
        tracking[name] = dict(sha256=sha, url=w.ASSETS[name])
    write(target/'tracking_sources.json', tracking)

    # Recorded normalized windows, one clip per category. Stays local/ignored.
    fixture = APP/'android/app/src/test/resources/parity'
    fixture.mkdir(parents=True, exist_ok=True)
    cases = []
    for symptom in c.CLASSES:
        clip = table[table.symptom.astype(str) == symptom].iloc[0]
        df = pq.read_table(run/'frames.parquet', filters=[('video_id', '=', str(clip.video_id))]).to_pandas()
        df = df.sort_values('timestamp_ms')
        t = df.timestamp_ms.to_numpy(dtype=float)/1000
        t -= t[0]
        start = float(clip.win_start_s)
        mask = (t >= start) & (t <= start+4.1)
        df, t = df.loc[mask], t[mask]
        columns = c.landmark_cols() + bs + fm + c.FLAG_COLS
        rows = df[columns].to_numpy(dtype=np.float32).astype(float)
        for variant in ('recorded', 'missing', 'sparse'):
            tt, rr = t.copy(), rows.copy()
            if variant == 'missing':
                rr[::3, :20] = np.nan
                rr[:, columns.index(bs[0])] = np.nan
            if variant == 'sparse':
                tt, rr = tt[::3], rr[::3]
                rr[:max(1, len(rr)//2+1), :10] = np.nan
            _, ss = c.compute_signals({n: rr[:, i] for i, n in enumerate(c.landmark_cols())})
            offset = len(c.landmark_cols())
            _, vals = c.clip_window_features(tt, ss, np.ascontiguousarray(rr[:, offset:offset+len(bs)], dtype=np.float32),
                np.ascontiguousarray(rr[:, offset+len(bs):offset+len(bs)+len(fm)], dtype=np.float32),
                np.ascontiguousarray(rr[:, -4:], dtype=np.float32), window_starts=[start])
            vals = vals.astype(np.float32)[0]
            vals = vals[[extracted_features.index(f) for f in features]]
            probs = [float(lgb.Booster(model_file=str(target/m['file'])).predict(vals[None, model_indices[i]], num_threads=1)[0]) for i,m in enumerate(models)]
            cases.append(dict(name=f'{symptom}_{variant}', start=start, times=tt, columns=columns, rows=rr, features=vals, probabilities=probs))
    write(fixture/'windows.json', cases)
    # Deterministic raw task-result cases independently exercise the adapter.
    from types import SimpleNamespace as NS
    raw_face = [NS(x=float(np.float32(.2+(i%21)*.025)), y=float(np.float32(.15+(i//21)*.025)), z=0.) for i in range(478)]
    raw_pose = [NS(x=float(np.float32(.25+(i%2)*.4)), y=float(np.float32(.2+i*.015)), z=0., visibility=1., presence=1.) for i in range(33)]
    raw_hands = [[NS(x=float(np.float32(raw_pose[wrist].x+j*.002)), y=float(np.float32(raw_pose[wrist].y+j*.001)), z=0.) for j in range(21)] for wrist in [16,15]]
    adapter_cases = []
    for variant in ['full_reversed_hands','one_hand','no_pose','missing_all','low_visibility','degenerate_reference']:
        f = [] if variant == 'missing_all' else raw_face
        p = [] if variant in ['missing_all','no_pose'] else [NS(**vars(v)) for v in raw_pose]
        hh = [] if variant == 'missing_all' else raw_hands[:1] if variant == 'one_hand' else raw_hands
        if variant == 'low_visibility':
            for idx in [11,12,25,26]: p[idx].visibility = .1
        if variant == 'degenerate_reference': p[12] = NS(**vars(p[11]))
        matrix = np.arange(16,dtype=np.float32).reshape(4,4)/17
        blend = {n[3:]: float(np.float32(i/len(bs))) for i,n in enumerate(bs)}
        fr = NS(face_landmarks=[f] if f else [], face_blendshapes=[[NS(category_name=k,score=v) for k,v in blend.items()]],facial_transformation_matrixes=[matrix])
        pr = NS(pose_landmarks=[p] if p else [])
        hr = NS(hand_landmarks=hh)
        row, tracking, _ = w.adapt_landmarks(fr,pr,hr,bs,fm)
        adapter_cases.append(dict(name=variant, face=[[v.x,v.y,v.z,v.__dict__.get('visibility',1),v.__dict__.get('presence',1)] for v in f],
            pose=[[v.x,v.y,v.z,v.__dict__.get('visibility',1),v.__dict__.get('presence',1)] for v in p],
            hands=[[[v.x,v.y,v.z,1,1] for v in hand] for hand in hh],blend=blend, packed_matrix=matrix.T.ravel(), row=row, tracking=tracking))
    write(fixture/'adapter.json',adapter_cases)
    # A small set of feature-only inputs checks native JNI inference on the JVM.
    vectors = table.loc[:, features].iloc[::113].to_numpy(dtype=np.float32)
    vectors = np.vstack([vectors, np.full((1, len(features)), np.nan, dtype=np.float32)])
    vectors[::7, ::3] = np.nan
    probs = np.column_stack([lgb.Booster(model_file=str(target/m['file'])).predict(vectors[:, model_indices[i]], num_threads=1) for i,m in enumerate(models)])
    write(fixture/'predictions.json', dict(features=vectors, probabilities=probs))
    write(APP/'.verification/export.json', dict(run_id=RUN_ID, feature_version=FEATURE_VERSION, mode=MODE,
        models=7, shared_features=len(features), features_per_model={m['symptom']:len(m['features']) for m in models}, windows_per_model=len(table),
        missing_cases_per_model=32, max_probability_error=max_error, tolerance=1e-12,
        recorded_window_cases=len(cases), lightgbm_version=lgb.__version__))
    print(f'Exported seven {FEATURE_VERSION}/{MODE} native models; {len(features)} shared features; {len(table)} windows/model + missing cases; max error {max_error}')


if __name__ == '__main__':
    main()
