import 'package:flutter/material.dart';
import 'allimages.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'googlesignin.dart';

void main() async {
  debugPrint('Current directory: ${Directory.current.path}');
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    anonKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoApp',
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session;

          if (session == null) {
            return const GoogleSignInPage();
          } else {
            return const MyHomePage(title: 'All Images');
          }
        },
      ),
    );
  }
}
