"""Create an ignored public-image reference for the Android MediaPipe check."""
import argparse
import json
from pathlib import Path
import sys
import urllib.request

from export_pipeline import APP, clean

ap = argparse.ArgumentParser()
ap.add_argument('--python-project', type=Path, required=True)
ap.add_argument('--lead', type=Path, help='anxiety_detection_prototype checkout; adds exporter pixel-space rows')
args = ap.parse_args()
sys.path.insert(0, str(args.python_project.resolve()))
import mediapipe as mp
from mediapipe.tasks.python import vision
from webcam_core import adapt_landmarks

folder = APP/'android/app/src/test/resources/parity'
url = 'https://storage.googleapis.com/mediapipe-assets/portrait.jpg'
image_path = folder/'portrait.jpg'
if not image_path.exists():
    image_path.write_bytes(urllib.request.urlopen(url, timeout=30).read())
manifest = json.loads((APP/'android/app/src/main/assets/behavior/manifest.json').read_text())
base = lambda name: mp.tasks.BaseOptions(model_asset_path=str(args.python_project/'tracking_assets'/name))
image = mp.Image.create_from_file(str(image_path))
with vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
        base_options=base('face_landmarker.task'), running_mode=vision.RunningMode.VIDEO,
        num_faces=1, output_face_blendshapes=True, output_facial_transformation_matrixes=True)) as face, \
     vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
        base_options=base('pose_landmarker_lite.task'), running_mode=vision.RunningMode.VIDEO)) as pose, \
     vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
        base_options=base('hand_landmarker.task'), running_mode=vision.RunningMode.VIDEO, num_hands=2)) as hands:
    face_result, pose_result = face.detect_for_video(image,0), pose.detect_for_video(image,0)
    row, tracking, _ = adapt_landmarks(face_result, pose_result,
        hands.detect_for_video(image,0), manifest['bs_names'], manifest['fm_names'])
pixel_row = {}
if args.lead:
    # The dataset exporter's own normalization (pixel space) for the same detections.
    import importlib.util
    spec = importlib.util.spec_from_file_location('allextractor', args.lead/'extractors/allextractor.py')
    extractor = importlib.util.module_from_spec(spec); spec.loader.exec_module(extractor)
    pixel_row.update(extractor.face_features(face_result.face_landmarks[0], image.width, image.height))
    if pose_result.pose_landmarks:
        pixel_row.update(extractor.pose_features(pose_result.pose_landmarks[0], image.width, image.height)[0])
    pixel_row = {k: v for k, v in pixel_row.items() if v != ''}
(folder/'portrait_reference.json').write_text(json.dumps(clean(dict(row=row,tracking=tracking,pixel_row=pixel_row,
    width=image.width, height=image.height, mediapipe_version=mp.__version__, source=url))), encoding='utf-8')
print('Reference image tracking:', tracking)

hand_url = 'https://storage.googleapis.com/mediapipe-assets/thumb_up.jpg'
hand_path = folder/'thumb_up.jpg'
if not hand_path.exists():
    hand_path.write_bytes(urllib.request.urlopen(hand_url, timeout=30).read())
hand_image = mp.Image.create_from_file(str(hand_path))
with vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
        base_options=base('hand_landmarker.task'), running_mode=vision.RunningMode.VIDEO, num_hands=2)) as hands:
    result = hands.detect_for_video(hand_image,0)
    assert len(result.hand_landmarks) == 1 and len(result.hand_landmarks[0]) == 21
    (folder/'hand_reference.json').write_text(json.dumps(dict(
        landmarks=[[[p.x,p.y,p.z] for p in hand] for hand in result.hand_landmarks],
        mediapipe_version=mp.__version__, source=hand_url)), encoding='utf-8')
print('Reference hand image: 21 landmarks')
