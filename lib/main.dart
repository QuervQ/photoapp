import 'dart:async';
import 'package:flutter/material.dart';
import 'allimages.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  Future<void> googlesignin() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    unawaited(
      googleSignIn.initialize(
        clientId: dotenv.get('GCP_IOS_CLIENT_ID'),
        serverClientId: dotenv.get('GCP_WEB_CLIENT_ID'),
      ),
    );
    final googleAccount = await googleSignIn.authenticate();
    final googleAuthorization = await googleAccount.authorizationClient
        .authorizationForScopes([]);
    final googleAuthentication = googleAccount.authentication;
    final idToken = googleAuthentication.idToken;
    final accessToken = googleAuthorization?.accessToken;

    if (idToken == null) {
      throw Exception('ID token is null');
    }

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await googlesignin();
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => const MyHomePage(title: 'All Images'),
                    ),
                  );
                }
              },
              child: const Text('Google Sign-In'),
            ),
          ],
        ),
      ),
    );
  }
}
