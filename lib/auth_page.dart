import 'package:flutter/material.dart';

import 'backend_api.dart';

class AuthPage extends StatefulWidget {
  final BackendApi api;
  final void Function(AuthSession session) onAuthenticated;

  const AuthPage({super.key, required this.api, required this.onAuthenticated});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスとパスワードを入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final session =
          _isLogin
              ? await widget.api.login(email: email, password: password)
              : await widget.api.signup(email: email, password: password);

      if (!mounted) return;
      widget.onAuthenticated(session);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('認証に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'ログイン' : '新規登録')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(_isLogin ? 'ログイン' : '新規登録'),
              ),
            ),
            TextButton(
              onPressed:
                  _isLoading
                      ? null
                      : () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
              child: Text(_isLogin ? 'アカウント作成へ' : 'ログインへ'),
            ),
          ],
        ),
      ),
    );
  }
}
