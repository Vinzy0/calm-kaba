import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BehaviorCameraPreview extends StatelessWidget {
  final VoidCallback onReady;
  const BehaviorCameraPreview({super.key, required this.onReady});
  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Camera detection requires Android',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return AndroidView(
      viewType: 'calm/camera',
      onPlatformViewCreated: (_) => onReady(),
    );
  }
}
