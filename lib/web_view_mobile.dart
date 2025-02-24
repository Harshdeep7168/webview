import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'profile_settings_page.dart';
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
  String? authToken;

  @override
  void initState() {
    super.initState();

    // Create platform-specific controller with appropriate optimizations
    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      // Removed the problematic AndroidWebStorage line
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = PlatformWebViewControllerCreationParams();
    }

    controller = WebViewController.fromPlatformCreationParams(params);

    // Configure controller settings
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(true) // Enable zoom for better user experience
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => isLoading = true);
            print("CUSTOM_LOG: Page loading started: $url");
          },
          onPageFinished: (String url) {
            setState(() => isLoading = false);
            print("CUSTOM_LOG: Page finished loading: $url");

            // Extract token when user is on a page after login
            // Check for a more comprehensive set of possible authenticated paths
            if (url.contains('/user/') || 
                url.contains('/dashboard/') || 
                url.contains('/account/') || 
                url.contains('/profile/')) {
              _extractAuthToken();
            }

            // Inject JavaScript to handle file inputs
            _injectFileInputScript();
          },
          onWebResourceError: (WebResourceError error) {
            print("CUSTOM_LOG: WebView error: ${error.description}");
            // Consider showing a user-friendly error message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Page loading error: ${error.description}')),
              );
            }
          },
          // Add navigation handling for external URLs
          onNavigationRequest: (NavigationRequest request) {
            // Handle external links (email, phone, etc.)
            if (request.url.startsWith('mailto:') || 
                request.url.startsWith('tel:') || 
                request.url.startsWith('sms:')) {
              // You can implement a URL launcher here
              print("CUSTOM_LOG: External URL detected: ${request.url}");
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            
            if (data is Map) {
              if (data['type'] == 'token' && data['value'] != null) {
                final token = data['value'].toString();
                print("CUSTOM_LOG: Token received from WebView");
                _saveToken(token);
                setState(() {
                  authToken = token;
                });
              } else if (data['type'] == 'token_error') {
                print("CUSTOM_LOG: Token error: ${data['value']}");
              }
            } else if (message.message == 'openProfileSettings') {
              _openProfileSettings();
            }
          } catch (e) {
            print("CUSTOM_LOG: Error processing JavaScript message: $e");
          }
        },
      );

    // Load the URL with proper error handling
    try {
      final uri = Uri.parse(widget.url);
      controller.loadRequest(uri);
    } catch (e) {
      print("CUSTOM_LOG: Error loading URL: $e");
      // Handle invalid URL gracefully
    }
  }

  // Extract authentication token from localStorage with improved error handling
  void _extractAuthToken() {
    print("CUSTOM_LOG: Attempting to extract token");
    const script = '''
      (function() {
        try {
          var token = localStorage.getItem('accessToken');
          if (token) {
            console.log("Token found in localStorage");
            window.Flutter.postMessage(JSON.stringify({
              type: 'token',
              value: token
            }));
          } else {
            // Try alternative token keys that might be used
            var altTokens = ['auth_token', 'jwt_token', 'token', 'userToken'];
            for (var i = 0; i < altTokens.length; i++) {
              token = localStorage.getItem(altTokens[i]);
              if (token) {
                console.log("Token found with key: " + altTokens[i]);
                window.Flutter.postMessage(JSON.stringify({
                  type: 'token',
                  value: token
                }));
                return;
              }
            }
            
            console.log("No token found in localStorage");
            window.Flutter.postMessage(JSON.stringify({
              type: 'token_error',
              value: 'Token not found in localStorage'
            }));
          }
        } catch (error) {
          console.error("Error accessing localStorage:", error);
          window.Flutter.postMessage(JSON.stringify({
            type: 'token_error',
            value: error.toString()
          }));
        }
      })();
    ''';

    controller.runJavaScript(script).catchError((error) {
      print("CUSTOM_LOG: Error executing JavaScript: $error");
    });
  }

  // Save token to SharedPreferences with improved security
  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      
      // Only log a small part of the token for security
      final truncatedToken = token.length > 10 
          ? '${token.substring(0, 5)}...${token.substring(token.length - 5)}' 
          : '[token too short]';
          
      print("CUSTOM_LOG: Token saved to SharedPreferences: $truncatedToken");
    } catch (e) {
      print("CUSTOM_LOG: Error saving token: $e");
    }
  }

  // Inject JavaScript to handle file inputs with improved styling and accessibility
  void _injectFileInputScript() {
    const script = '''
      (function() {
        try {
          const fileInputs = document.querySelectorAll('input[type="file"]');
          console.log("Found " + fileInputs.length + " file inputs on page");
          
          fileInputs.forEach((input, index) => {
            // Check if button is already added to avoid duplicates
            if (input.getAttribute('flutter-handled') === 'true') {
              return;
            }
            
            input.setAttribute('flutter-handled', 'true');
            input.setAttribute('disabled', 'true');
            
            // Create a button with better styling
            const button = document.createElement('button');
            button.id = 'flutter-upload-btn-' + index;
            button.innerText = 'Upload Photo';
            button.style.marginLeft = '10px';
            button.style.padding = '8px 16px';
            button.style.backgroundColor = '#1976d2';
            button.style.color = 'white';
            button.style.border = 'none';
            button.style.borderRadius = '4px';
            button.style.cursor = 'pointer';
            button.style.fontSize = '14px';
            button.style.fontWeight = 'bold';
            button.setAttribute('aria-label', 'Upload Photo');
            button.setAttribute('role', 'button');
            
            // Add hover effect
            button.addEventListener('mouseover', () => {
              button.style.backgroundColor = '#1565c0';
            });
            button.addEventListener('mouseout', () => {
              button.style.backgroundColor = '#1976d2';
            });
            
            button.addEventListener('click', (e) => {
              e.preventDefault();
              e.stopPropagation();
              console.log("Upload button clicked");
              // Call Flutter method for navigation
              window.Flutter.postMessage('openProfileSettings');
            });
            
            // Insert after the input
            if (input.parentNode) {
              input.parentNode.insertBefore(button, input.nextSibling);
              console.log("Added upload button for input #" + index);
            }
          });
        } catch (error) {
          console.error("Error in file input script:", error);
        }
      })();
    ''';

    controller.runJavaScript(script).catchError((error) {
      print("CUSTOM_LOG: Error injecting file input script: $error");
    });
  }

  void _openProfileSettings() {
    // Remove the authToken named parameter if it's not defined in ProfileSettingsPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button press to navigate within WebView if possible
        if (await controller.canGoBack()) {
          await controller.goBack();
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          SizedBox.expand(
            child: WebViewWidget(controller: controller),
          ),
          if (isLoading)
            Container(
              color: Colors.white.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Add a floating action button for quick settings access
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom +
                kBottomNavigationBarHeight +
                16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _openProfileSettings,
              backgroundColor: Theme.of(context).primaryColor,
              tooltip: 'Settings',
              child: const Icon(Icons.settings, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}