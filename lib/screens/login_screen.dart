import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/hive_service.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final HiveService hiveService;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.hiveService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signInAnonymously() async {
    setState(() { _isLoading = true; _error = null; });
    final result = await widget.authService.signInAnonymously();
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else {
      setState(() { _error = result.error; _isLoading = false; });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _error = null; });
    final result = await widget.authService.signInWithGoogle();
    if (!mounted) return;
    if (result.success) {
      final profile = result.profile!;
      // Если профиль уже заполнен (вес есть) — на главную, иначе онбординг
      final route = profile.weight != null ? '/home' : '/onboarding';
      Navigator.of(context).pushReplacementNamed(route);
    } else {
      setState(() { _error = result.error; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Логотип
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.35),
                      blurRadius: 24, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.water_drop_rounded,
                    color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),

              const Text(
                'AquaTrack',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Умный контроль гидратации\nс учётом вашей активности',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),

              // Ошибка
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                // Google Sign-In
                _GoogleButton(onTap: _signInWithGoogle),
                const SizedBox(height: 12),

                // Разделитель
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('или',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ]),
                const SizedBox(height: 12),

                // Анонимный вход
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _signInAnonymously,
                    icon: const Icon(Icons.person_outline_rounded),
                    label: const Text('Продолжить без аккаунта'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Без аккаунта история не сохраняется\nпри смене устройства',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google G иконка через SVG-like контейнер
            Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: const Text('G',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF4285F4),
                )),
            ),
            const SizedBox(width: 10),
            const Text('Войти через Google',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
