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
      title: 'DeskOs',
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