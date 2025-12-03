import 'package:flutter/material.dart';
import 'allimages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  debugPrint('Current directory: ${Directory.current.path}');
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: GoogleSignInpage(title: 'Image apps'),
    );
  }
}

class GoogleSignInpage extends StatefulWidget {
  final String title;

  const GoogleSignInpage({super.key, required this.title});

  @override
  State<GoogleSignInpage> createState() => _GoogleSignInState();
}

class _GoogleSignInState extends State<GoogleSignInpage> {
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      // サインアウトに失敗しても無視する
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Login')),
      body: Center(
        child: Column(
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                // サインイン画面を表示する
                final userCredential = await signInWithGoogle();

                if (userCredential != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => const MyHomePage(title: 'Image apps'),
                    ),
                  );
                }
              },
              child: const Text('Google'),
            ),
          ],
        ),
      ),
    );
  }
}
