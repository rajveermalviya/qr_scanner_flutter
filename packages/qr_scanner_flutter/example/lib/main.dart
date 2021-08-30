import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_scanner_flutter/qr_scanner.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: TextButton(
            child: Text('Open scanner'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => QrScannerPage(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({Key? key}) : super(key: key);

  @override
  _QrScannerPageState createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  late QrScannerController _controller;
  late StreamSubscription<String> _barcodeSub;

  @override
  void initState() {
    _intialize();
    super.initState();
  }

  Future<void> _intialize() async {
    _controller = QrScannerController();
    await _controller.initialize();

    _barcodeSub = _controller.barcodeStream.listen((code) {
      debugPrint(DateTime.now().toString() + ':' + code);
    });
  }

  @override
  void dispose() {
    _barcodeSub.cancel();
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qr Scanner'),
      ),
      body: QrScannerPreview(
        controller: _controller,
      ),
    );
  }
}
