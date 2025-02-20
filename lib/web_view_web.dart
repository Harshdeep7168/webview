import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

class PlatformWebView extends StatefulWidget {
  final String url;

  const PlatformWebView({Key? key, required this.url}) : super(key: key);

  @override
  State<PlatformWebView> createState() => _PlatformWebViewState();
}

class _PlatformWebViewState extends State<PlatformWebView> {
  final String viewType = 'iframe-view';
  late final String targetUrl;

  @override
  void initState() {
    super.initState();
    targetUrl = widget.url;

    // Register the iframe view - updated CSS to make it full screen
    ui.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = targetUrl
          ..style.border = 'none'
          ..style.height = '100%'
          ..style.width = '100%'
          ..style.position = 'absolute'
          ..style.top = '0'
          ..style.left = '0'
          ..style.margin = '0'
          ..style.padding = '0'
          ..allowFullscreen = true;
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fill the entire space
    return SizedBox.expand(
      child: HtmlElementView(viewType: viewType),
    );
  }
}
