import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AdminLoginView extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoggingIn;
  final String? loginError;
  final VoidCallback onSubmit;

  const AdminLoginView({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLoggingIn,
    required this.loginError,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Login Admin Panel'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.admin_panel_settings,
                    size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Panel Moderasi & KYC',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masuk menggunakan kredensial PocketBase Superuser untuk memverifikasi KYC & moderasi konten.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (loginError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      loginError!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Superuser Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata Sandi Superuser',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: isLoggingIn ? null : onSubmit,
                  child: isLoggingIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Masuk ke Dashboard Admin'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
