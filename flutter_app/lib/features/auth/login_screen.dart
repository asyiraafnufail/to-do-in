import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/repositories/repositories.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegister = false;
  bool _isLoading = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email dan kata sandi wajib diisi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isRegister) {
        final username = _usernameCtrl.text.trim().toLowerCase();
        if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(username)) {
          setState(() {
            _isLoading = false;
            _error =
                'Username harus 3-20 karakter (huruf kecil, angka, titik, underscore).';
          });
          return;
        }
        await authRepo.register(
          email: email,
          password: password,
          username: username,
          name: _nameCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Akun berhasil dibuat. Cek email $email untuk verifikasi.'),
            ),
          );
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go('/feed');
          }
        }
        return;
      }

      final isAdmin = await authRepo.login(email, password);

      if (mounted) {
        if (isAdmin) {
          context.go('/admin');
        } else if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/feed');
        }
      }
    } on ClientException catch (e) {
      final data = e.response['data'];
      if (data is Map && data.isNotEmpty) {
        final details = data.entries
            .map((entry) =>
                '${entry.key}: ${(entry.value is Map ? entry.value['message'] : null) ?? entry.value}')
            .join('\n');
        setState(() => _error = details);
      } else {
        final msg = e.response['message']?.toString() ?? 'Autentikasi gagal.';
        setState(() => _error = msg);
      }
    } catch (_) {
      setState(() => _error = 'Tidak dapat terhubung ke server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lupa Kata Sandi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan email akun Anda. Kami akan mengirim tautan untuk mengatur ulang kata sandi.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'nama@email.com',
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Kirim Tautan'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (email == null || !mounted) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Format email tidak valid.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await authRepo.requestPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Jika $email terdaftar, tautan reset kata sandi telah dikirim.'),
          ),
        );
      }
    } on ClientException catch (e) {
      setState(() => _error =
          e.response['message']?.toString() ?? 'Gagal mengirim tautan reset.');
    } catch (_) {
      setState(() => _error = 'Tidak dapat terhubung ke server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await authRepo.loginWithGoogle((url) async {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      });

      if (mounted) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/feed');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gagal masuk dengan Google.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_isRegister ? 'Daftar Akun' : 'Masuk ke todoin.id'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo_full.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isRegister ? 'Buat Akun Baru' : 'Selamat Datang Kembali',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegister
                      ? 'Bagikan cerita perjalanan terverifikasi GPS & rencanakan liburan.'
                      : 'Masuk untuk menulis cerita, simpan To-Do, & hubungi guide lokal.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isRegister) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      hintText: 'Budi Santoso',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'budi_jalan',
                      prefixText: '@',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'nama@email.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata Sandi',
                    hintText: 'Minimal 8 karakter',
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (!_isRegister)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _showForgotPasswordDialog,
                      child: const Text(
                        'Lupa kata sandi?',
                        style: TextStyle(
                            color: AppColors.primary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isRegister ? 'Daftar Sekarang' : 'Masuk'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _isRegister = !_isRegister;
                            _error = null;
                          }),
                  child: Text(
                    _isRegister
                        ? 'Sudah punya akun? Masuk di sini'
                        : 'Belum punya akun? Daftar sekarang',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'atau',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _loginWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: const Text('Lanjutkan dengan Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
