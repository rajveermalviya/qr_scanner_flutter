import 'package:flutter/widgets.dart';

import 'qr_scanner_controller.dart';

class QrScannerPreview extends StatelessWidget {
  final QrScannerController controller;
  final Widget loaderWidget;

  const QrScannerPreview({
    Key? key,
    required this.controller,
    this.loaderWidget = const Text('Loading ...'),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.cameraInitialized,
      builder: (context, cameraInitialized, child) => cameraInitialized
          ? ClipRect(
              child: Transform.scale(
                scale: controller.size.fill(MediaQuery.of(context).size),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.size.aspectRatio,
                    child: Texture(textureId: controller.textureId),
                  ),
                ),
              ),
            )
          : loaderWidget,
    );
  }
}

extension on Size {
  double fill(Size targetSize) {
    if (targetSize.aspectRatio < aspectRatio) {
      return targetSize.height * aspectRatio / targetSize.width;
    } else {
      return targetSize.width / aspectRatio / targetSize.height;
    }
  }
}
