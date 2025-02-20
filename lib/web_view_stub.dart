import 'package:flutter/material.dart';

// This is a stub implementation that won't be used at runtime
class PlatformWebView extends StatelessWidget {
  final String url;
  
  const PlatformWebView({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('WebView not supported on this platform'),
    );
  }
}