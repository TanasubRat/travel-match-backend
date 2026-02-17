import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_button.dart';

class LoginScreen extends StatefulWidget {
  final ApiService api;
  const LoginScreen({super.key, required this.api});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final body = {
        'email': _email.text.trim(),
        'password': _password.text,
      };
      final res = await widget.api.rawPost('/api/auth/login', body: body);
      final token = res['token'] as String?;
      if (token == null) throw Exception('No token in response');

      try {
        widget.api.setToken(token);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: SafeArea(
        child: TextButton(
          onPressed: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Welcome back',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 12),

                  // ---- Email ----
                  AppTextField(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefix: const Icon(Icons.email_outlined),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Enter your email address';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(s)) {
                        return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ---- Password ----
                  AppTextField(
                    controller: _password,
                    label: 'Password',
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Password must be at least 6 characters.'
                        : null,
                    onSubmitted: (_) => _submit(),
                  ),

                  const Spacer(),

                  // ---- Submit Button ----
                  PrimaryButton(
                    label: _loading ? 'Logging in…' : 'Log in',
                    icon: Icons.login,
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.pushReplacementNamed(
                            context, '/register'),
                    child: const Text("Don't have an account? Sign up."),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
