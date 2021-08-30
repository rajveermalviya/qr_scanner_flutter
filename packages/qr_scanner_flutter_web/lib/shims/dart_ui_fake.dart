import 'dart:html' as html;

// ignore: camel_case_types
class platformViewRegistry {
  static registerViewFactory(
      String viewTypeId, html.Element Function(int viewId) viewFactory) {}
}

// ignore: camel_case_types
class webOnlyAssetManager {
  static getAssetUrl(String asset) {}
}

typedef VoidCallback = void Function();
