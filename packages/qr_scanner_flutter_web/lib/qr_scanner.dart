import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class QrScannerController {
  static const channel = MethodChannel('qr_scanner_flutter.rajveermalviya.dev');

  final ValueNotifier<bool> cameraInitialized = ValueNotifier(false);
  int? textureId;

  late StreamController<String> _barcodeStreamController;
  Stream<String> get barcodeStream => _barcodeStreamController.stream;

  Future<void> initialize() async {
    _barcodeStreamController = StreamController.broadcast();
    channel.setMethodCallHandler(_onMethodCall);

    final res = await channel.invokeMethod('initialize');
    textureId = res['texture_id'];
    cameraInitialized.value = true;
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'barcodeDetected':
        return _barcodeStreamController.add(call.arguments as String);
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: '\'${call.method}\' is unimplemented',
        );
    }
  }

  Future<void> dispose() async {
    cameraInitialized.value = false;
    await channel.invokeMethod('dispose');

    channel.setMethodCallHandler(null);
    await _barcodeStreamController.close();
  }
}

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
          ? HtmlElementView(
              viewType:
                  'qr_scanner_flutter.rajveermalviya.dev/camera/${controller.textureId}',
            )
          : loaderWidget,
    );
  }
}
