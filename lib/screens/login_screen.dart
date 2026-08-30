import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  void _login() async {
    final auth = context.read<AuthProvider>();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;
    if (user.isEmpty || pass.isEmpty) return;
    await auth.login(user, pass);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // Title bar
          WindowTitleBarBox(
            child: Container(
              color: AppColors.navyDark,
              child: Row(
                children: [
                  Expanded(child: MoveWindow()),
                  const _LoginWindowButtons(),
                ],
              ),
            ),
          ),

          Expanded(
            child: Row(
              children: [
                // ── Left branding panel ───────────────────────────────────
                Expanded(
                  child: Container(
                    color: AppColors.navyDark,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              'R',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 40,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'RECOVERA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Client Relationship Management',
                          style: TextStyle(
                            color: AppColors.sidebarText,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Container(
                          width: 200,
                          height: 1,
                          color: const Color(0x30FFFFFF),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          '"Recover more. Faster."',
                          style: TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Right login form ───────────────────────────────────────
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHead,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Enter your credentials to access the CRM.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Error banner
                          if (auth.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusRedBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.statusRed.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.statusRed,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      auth.errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.statusRed,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Username
                          const Text(
                            'USERNAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter username',
                              prefixIcon: Icon(Icons.person_outline, size: 18),
                            ),
                            onChanged: (_) => auth.clearError(),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 18),

                          // Password
                          const Text(
                            'PASSWORD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              hintText: 'Enter password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                splashRadius: 18,
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                            onChanged: (_) => auth.clearError(),
                          ),
                          const SizedBox(height: 28),

                          // Login button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginWindowButtons extends StatelessWidget {
  const _LoginWindowButtons();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MinimizeWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            mouseOver: AppColors.navyLight,
          ),
        ),
        MaximizeWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            mouseOver: AppColors.navyLight,
          ),
        ),
        CloseWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            mouseOver: const Color(0xFFE81123),
          ),
        ),
      ],
    );
  }
}

// Keep WindowButtons exported for backwards-compat
class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MinimizeWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            mouseOver: AppColors.navyLight,
          ),
        ),
        MaximizeWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            mouseOver: AppColors.navyLight,
          ),
        ),
        CloseWindowButton(
          colors: WindowButtonColors(
            iconNormal: Colors.white60,
            mouseOver: const Color(0xFFE81123),
          ),
        ),
      ],
    );
  }
}
