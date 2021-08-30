import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class QrScannerController {
  static const channel = MethodChannel('qr_scanner_flutter.rajveermalviya.dev');

  final ValueNotifier<bool> cameraInitialized = ValueNotifier(false);
  late int textureId;
  late Size size;

  late StreamController<String> _barcodeStreamController;
  Stream<String> get barcodeStream => _barcodeStreamController.stream;

  Future<void> initialize() async {
    _barcodeStreamController = StreamController.broadcast();
    channel.setMethodCallHandler(_onMethodCall);

    try {
      await channel.invokeMethod('initialize');
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  Future<void> dispose() async {
    await channel.invokeMethod('dispose');

    channel.setMethodCallHandler(null);
    await _barcodeStreamController.close();

    cameraInitialized.value = false;
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'cameraInitialized':
        return _cameraInitialized(call);
      case 'barcodeDetected':
        return _barcodeStreamController.add(call.arguments as String);
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: '\'${call.method}\' is unimplemented',
        );
    }
  }

  Future<void> _cameraInitialized(MethodCall call) async {
    final dataMap = call.arguments as Map<dynamic, dynamic>;
    textureId = dataMap["texture_id"] as int;
    final width = dataMap["width"] as double;
    final height = dataMap["height"] as double;
    size = Size(width, height);
    cameraInitialized.value = true;
  }
}
