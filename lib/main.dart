import 'package:flutter/material.dart';
import 'auth_page.dart';
import 'backend_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'multiplayer_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'PhotoApp', home: AppRoot());
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final BackendApi _api = BackendApi();
  AuthSession? _session;

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return AuthPage(
        api: _api,
        onAuthenticated: (session) {
          setState(() {
            _session = session;
          });
        },
      );
    }

    return MultiplayerPage(
      api: _api,
      session: _session!,
      onLogout: () {
        setState(() {
          _session = null;
        });
      },
    );
  }
}
