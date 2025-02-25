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
  String currentUrl = '';

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
            setState(() {
              isLoading = true;
              currentUrl = url;
            });
            print("CUSTOM_LOG: Page loading started: $url");
            
            // Check if URL contains user/settings and navigate to profile settings
            if (url.contains('/user/settings')) {
              _openProfileSettings();
            }
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
              currentUrl = url;
            });
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
            
            // Check again for user/settings path in case it was missed in onPageStarted
            if (url.contains('/user/settings')) {
              _openProfileSettings();
            }
          },
          onUrlChange: (UrlChange change) {
            final url = change.url;
            if (url != null) {
              setState(() => currentUrl = url);
              print("CUSTOM_LOG: URL changed to: $url");
              
              // Check if URL contains user/settings and navigate to profile settings
              if (url.contains('/user/settings')) {
                _openProfileSettings();
              }
            }
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
            // Handle user/settings path
            if (request.url.contains('/user/settings')) {
              _openProfileSettings();
              return NavigationDecision.prevent;
            }
            
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
            if (message.message == 'openProfileSettings') {
              _openProfileSettings();
              return;
            }
            
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
              } else if (data['type'] == 'navigate' && data['to'] == 'profileSettings') {
                _openProfileSettings();
              }
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
    
    // Add JavaScript to monitor URL changes
    _injectUrlChangeMonitor();
  }
  
  // Inject script to monitor URL changes and detect user/settings path
  void _injectUrlChangeMonitor() {
    const script = '''
      (function() {
        // Monitor URL changes using mutation observer
        let lastUrl = location.href;
        
        // Create a new observer to watch for URL changes
        const observer = new MutationObserver(() => {
          if (location.href !== lastUrl) {
            lastUrl = location.href;
            console.log('URL changed to: ' + lastUrl);
            
            // Check if the URL contains /user/settings
            if (lastUrl.includes('/user/settings')) {
              console.log('Detected user/settings in URL');
              window.Flutter.postMessage(JSON.stringify({
                type: 'navigate',
                to: 'profileSettings'
              }));
            }
          }
        });
        
        // Start observing the document with configured parameters
        observer.observe(document, { subtree: true, childList: true });
        
        // Also check the current URL
        if (location.href.includes('/user/settings')) {
          console.log('Initial URL contains user/settings');
          window.Flutter.postMessage(JSON.stringify({
            type: 'navigate',
            to: 'profileSettings'
          }));
        }
      })();
    ''';

    controller.runJavaScript(script).catchError((error) {
      print("CUSTOM_LOG: Error injecting URL monitor script: $error");
    });
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
    // Only navigate if we're not already on the profile settings page
    // This prevents multiple navigation attempts
    if (!Navigator.of(context).canPop() || 
        !(ModalRoute.of(context)?.settings.name == '/profile_settings')) {
      print("CUSTOM_LOG: Navigating to profile settings page");
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/profile_settings'),
          builder: (context) => const ProfileSettingsPage(),
        ),
      );
    } else {
      print("CUSTOM_LOG: Already on profile settings page, skipping navigation");
    }
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