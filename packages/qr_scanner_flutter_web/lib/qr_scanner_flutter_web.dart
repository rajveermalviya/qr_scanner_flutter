import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'shims/dart_ui.dart' as ui;

typedef ScanQrCodeFunction = String? Function(html.ImageData);

class QrScannerFlutterWeb {
  final MethodChannel channel;
  QrScannerFlutterWeb(this.channel);

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'qr_scanner_flutter.rajveermalviya.dev',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = QrScannerFlutterWeb(channel);
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'initialize':
        return _initialize();
      case 'dispose':
        return _dispose();
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'qr_scanner_flutter_web for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  int textureId = 0;
  html.DivElement? _divElement;
  html.VideoElement? _videoElement;
  html.MediaStream? _stream;

  Timer? _timer;

  Future<Map<String, int>> _initialize() async {
    _dispose();

    if (!js.context.hasProperty('scanQrCode'))
      throw PlatformException(
        code: 'function-not-found',
        message: 'window.scanQrCode function is not defined',
      );

    final mediaDevices = html.window.navigator.mediaDevices;

    // Throw a not supported exception if the current browser window
    // does not support any media devices.
    if (mediaDevices == null)
      throw PlatformException(
        code: 'camera-not-supported',
        message: 'The camera is not supported on this device.',
      );

    _stream = await mediaDevices.getUserMedia({
      'video': {
        'width': 1280,
        'height': 720,
        'facingMode': {'exact': 'environment'},
      },
      'audio': false
    });

    _videoElement = html.VideoElement();

    _videoElement!.style
      ..pointerEvents = 'none'
      ..width = '100%'
      ..height = '100%'
      ..transformOrigin = 'center'
      ..objectFit = 'cover';

    _videoElement!
      ..autoplay = true
      ..muted = true
      ..srcObject = _stream
      ..setAttribute('playsinline', '');

    _divElement = html.DivElement()
      ..style.setProperty('object-fit', 'cover')
      ..append(_videoElement!);

    textureId++;
    ui.platformViewRegistry.registerViewFactory(
      'qr_scanner_flutter.rajveermalviya.dev/camera/$textureId',
      (_) => _divElement!,
    );

    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        final videoWidth = _videoElement!.videoWidth;
        final videoHeight = _videoElement!.videoHeight;
        final canvas =
            html.CanvasElement(width: videoWidth, height: videoHeight);

        canvas.context2D
          ..translate(videoWidth, 0)
          ..scale(-1, 1)
          ..drawImageScaled(_videoElement!, 0, 0, videoWidth, videoHeight);
        final image =
            canvas.context2D.getImageData(0, 0, videoWidth, videoHeight);

        final result = js.context.callMethod('scanQrCode', [image]) as String?;
        if (result == null || result.isEmpty) return;

        channel.invokeMethod('barcodeDetected', result);
      },
    );

    return {'texture_id': textureId};
  }

  void _dispose() {
    _timer?.cancel();

    final tracks = _videoElement?.srcObject?.getTracks();
    if (tracks != null) for (final track in tracks) track.stop();

    _timer = null;
    _videoElement?.srcObject = null;
    _videoElement = null;
    _divElement = null;
    _stream = null;
  }
}
