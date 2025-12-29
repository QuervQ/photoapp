import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'allimages.dart';

final supabase = Supabase.instance.client;

class GoogleSignInPage extends StatelessWidget {
  const GoogleSignInPage({super.key});

  Future<void> googlesignin(BuildContext context) async {
    final googleSignIn = GoogleSignIn.instance;

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

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MyHomePage(title: 'All Images'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => googlesignin(context),
          child: const Text('Google Sign-In'),
        ),
      ),
    );
  }
}
