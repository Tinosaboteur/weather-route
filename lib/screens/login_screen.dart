import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/message_box.dart';
import '../services/api_service.dart';
import '../widgets/social_login.dart';
import 'main_screen.dart';
import 'register_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '863153913211-kvcsaenb1448dnh0vec8psa3d0kjmn1u.apps.googleusercontent.com',
  );
  bool _isLoading = false;
  bool _obscure = true;
  String? _messageTitle;
  String? _messageBody;
  MessageType _messageType = MessageType.info;

  Future<void> _login() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _messageBody = null;
    });
    try {
      await authProvider.login(() async {
        await _apiService.login(_emailController.text, _passwordController.text);
      });

      if (mounted && authProvider.isAuthenticated) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messageTitle = "Lỗi đăng nhập";
          _messageBody = e.toString().replaceAll("Exception: ", "");
          _messageType = MessageType.error;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() { _isLoading = true; _messageBody = null; });
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Không thể lấy ID token. Vui lòng kiểm tra lại cấu hình SHA-1 và Test Users trên Google Cloud Console.');
      }

      await authProvider.login(() async {
        await _apiService.loginWithGoogle(idToken);
      });

      if (mounted && authProvider.isAuthenticated) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messageTitle = "Lỗi đăng nhập Google";
          _messageBody = e.toString().replaceAll("Exception: ", "");
          _messageType = MessageType.error;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _duotoneIcon(IconData icon) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        colors: [const Color(0xFF00D1FF), const Color(0xFF5A67F2)],
      ).createShader(rect),
      child: Icon(icon, size: 28),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({required String label, required IconData prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      prefixIcon: _duotoneIcon(prefix),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.primaryGradient();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Container(decoration: BoxDecoration(gradient: gradient)),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).cardColor.withOpacity(0.12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _duotoneIcon(Icons.login),
                        const SizedBox(height: 18),
                        if (_messageBody != null)
                          MessageBox(
                            title: _messageTitle ?? 'Thông báo',
                            message: _messageBody!,
                            type: _messageType,
                            onClose: () => setState(() => _messageBody = null),
                          ),
                        if (_messageBody != null) const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: _inputDecoration(label: 'Email', prefix: Icons.email),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: _inputDecoration(
                            label: 'Mật khẩu',
                            prefix: Icons.lock,
                            suffix: IconButton(
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          obscureText: _obscure,
                        ),
                        const SizedBox(height: 12),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(30)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                child: const Text('Đăng nhập', style: TextStyle(fontSize: 20, color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                            backgroundColor: Colors.blue.shade50,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('Chưa có tài khoản? Đăng ký ngay!'),
                        ),
                        SocialLoginButtons(
                          onGoogleSignIn: _isLoading ? null : handleGoogleSignIn,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: _isLoading ? null : () {
                      Provider.of<AuthProvider>(context, listen: false).setGuestMode();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text('Tiếp tục với tư cách khách'),
                  ),

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}