import 'package:flutter/material.dart';

/// Abstract class for platform-specific WebView implementations
abstract class WebViewStub extends StatefulWidget {
  const WebViewStub({Key? key}) : super(key: key);
}

/// Stub implementation that will be replaced by platform-specific implementations
class PlatformWebView extends StatefulWidget {
  final String url;
  
  const PlatformWebView({Key? key, required this.url}) : super(key: key);
  
  @override
  State<PlatformWebView> createState() {
    throw UnimplementedError('PlatformWebView is not implemented for this platform');
  }
}