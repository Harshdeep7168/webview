// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:webview_flutter_android/webview_flutter_android.dart';
// import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
// // Import for web platform detection
// import 'dart:io' show Platform;

// void main() {
//   // Ensure Flutter is initialized
//   WidgetsFlutterBinding.ensureInitialized();
  
//   // Set up platform-specific controllers based on the platform
//   if (!kIsWeb) {
//     if (Platform.isAndroid) {
//       WebViewPlatform.instance = AndroidWebViewPlatform();
//     } else if (Platform.isIOS) {
//       WebViewPlatform.instance = WebKitWebViewPlatform();
//     }
//   }
  
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Deskos Demo',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: const WebViewPage(),
//     );
//   }
// }

// class WebViewPage extends StatefulWidget {
//   const WebViewPage({Key? key}) : super(key: key);

//   @override
//   State<WebViewPage> createState() => _WebViewPageState();
// }

// class _WebViewPageState extends State<WebViewPage> {
//   bool isLoading = true;
  
//   // Check if we're running on web
//   final bool _isWeb = kIsWeb;
  
//   // WebViewController is only used on mobile platforms
//   late final WebViewController _controller;
  
//   @override
//   void initState() {
//     super.initState();
    
//     if (!_isWeb) {
//       _initMobileWebView();
//     }
//   }
  
//   void _initMobileWebView() {
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageStarted: (String url) {
//             setState(() {
//               isLoading = true;
//             });
//           },
//           onPageFinished: (String url) {
//             setState(() {
//               isLoading = false;
//             });
//           },
//           onWebResourceError: (WebResourceError error) {
//             debugPrint('WebView error: ${error.description}');
//           },
//         ),
//       )
//       ..loadRequest(Uri.parse('https://demo.deskos.net/'));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Deskos Demo'),
//         actions: [
//           if (!_isWeb)
//             IconButton(
//               icon: const Icon(Icons.refresh),
//               onPressed: () {
//                 _controller.reload();
//               },
//             ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           if (_isWeb)
//             // For web platform, use iframe
//             const Center(
//               child: Text(
//                 'Please run this app on a mobile device or use a direct browser link: https://demo.deskos.net/',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16),
//               ),
//             )
//           else
//             // For mobile platforms
//             WebViewWidget(controller: _controller),
          
//           if (isLoading && !_isWeb)
//             const Center(
//               child: CircularProgressIndicator(),
//             ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Conditional imports based on platform
import 'web_view_stub.dart'
    if (dart.library.html) 'web_view_web.dart'
    if (dart.library.io) 'web_view_mobile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deskos Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatelessWidget {
  const WebViewPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Removed AppBar - using a headerless Scaffold
    return const Scaffold(
      body: SafeArea(
        // SafeArea ensures content doesn't overlap with system UI
        child: PlatformWebView(url: 'https://demo.deskos.net/'),
      ),
    );
  }
}