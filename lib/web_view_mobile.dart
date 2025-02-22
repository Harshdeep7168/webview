import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io' show Platform;

class PlatformWebView extends StatefulWidget {
  final String url;

  const PlatformWebView({Key? key, required this.url}) : super(key: key);

  @override
  State<PlatformWebView> createState() => _PlatformWebViewState();
}

class _PlatformWebViewState extends State<PlatformWebView> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // Create platform-specific controller
    late final PlatformWebViewControllerCreationParams params;
    
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams();
    } else {
      params = PlatformWebViewControllerCreationParams();
    }

    controller = WebViewController.fromPlatformCreationParams(params);

    // Configure controller settings
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => isLoading = false);
            
            // Inject JavaScript to handle file inputs
            _injectFileInputScript();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );

    // Load the URL
    controller.loadRequest(Uri.parse(widget.url));
  }

  // Inject JavaScript to make file inputs read-only
  void _injectFileInputScript() {
    const script = '''
      (function() {
        const fileInputs = document.querySelectorAll('input[type="file"]');
        fileInputs.forEach(input => {
          input.setAttribute('disabled', 'true');
          
          // Create a button next to each file input
          const button = document.createElement('button');
          button.innerText = 'Choose File';
          button.style.marginLeft = '10px';
          button.addEventListener('click', (e) => {
            e.preventDefault();
            window.flutter_inappwebview.callHandler('fileUpload');
          });
          
          input.parentNode.insertBefore(button, input.nextSibling);
        });
      })();
    ''';

    controller.runJavaScript(script);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: WebViewWidget(controller: controller),
        ),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}