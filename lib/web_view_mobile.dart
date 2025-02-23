import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'profile_settings_page.dart'; // Import the profile settings page
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
          button.innerText = 'Upload Photo';
          button.style.marginLeft = '10px';
          button.style.padding = '8px 16px';
          button.style.backgroundColor = '#1976d2';
          button.style.color = 'white';
          button.style.border = 'none';
          button.style.borderRadius = '4px';
          button.style.cursor = 'pointer';
          
          button.addEventListener('click', (e) => {
            e.preventDefault();
            // Call Flutter method for navigation
            window.flutter.postMessage('openProfileSettings');
          });
          
          input.parentNode.insertBefore(button, input.nextSibling);
        });
      })();
    ''';

    controller.runJavaScript(script);
  }

  void _openProfileSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileSettingsPage()),
    );
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
        // Add a floating action button for quick settings access
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom +
              kBottomNavigationBarHeight +
              16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _openProfileSettings,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.settings, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
