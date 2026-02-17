import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_button.dart';

class RegisterScreen extends StatefulWidget {
  final ApiService api;
  const RegisterScreen({super.key, required this.api});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final body = {
        'displayName': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      };
      final res = await widget.api.rawPost('/api/auth/register', body: body);
      final token = res['token'] as String?;
      if (token == null) throw Exception('No token in response');

      try {
        widget.api.setToken(token);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successful Register')),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unsuccessful Register: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Get started',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---- Display name ----
                  AppTextField(
                    controller: _name,
                    label: 'Display name',
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Enter at least 2 characters of your name.'
                        : null,
                  ),
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
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Password must be at least 6 characters.'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // ---- Confirm password ----
                  AppTextField(
                    controller: _confirm,
                    label: 'Confirm password',
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) => (v == null || v != _password.text)
                        ? 'Passwords do not match'
                        : null,
                    onSubmitted: (_) => _submit(),
                  ),

                  const Spacer(),

                  // ---- Submit ----
                  PrimaryButton(
                    label: _loading ? 'Applying…' : 'Register',
                    icon: Icons.person_add_alt,
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _loading
                        ? null
                        : () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Already have an account? Log in'),
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
