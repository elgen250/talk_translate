import 'package:flutter/material.dart';
import 'camera_solutions_compare_view.dart';

export 'camera_solutions_compare_view.dart';

/// CameraTranslateView forwards directly to [CameraSolutionsCompareView],
/// providing a live interactive comparison lab of all 3 OCR solutions.
class CameraTranslateView extends StatelessWidget {
  const CameraTranslateView({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraSolutionsCompareView();
  }
}
