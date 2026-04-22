import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/message_box.dart';
import '../utils/app_theme.dart';
import '../widgets/social_login.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  MessageType _messageType = MessageType.info;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        String message = await _apiService.registerUser(
          _fullNameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          _phoneController.text.trim(),
        );
        if (mounted) {
          setState(() {
            _errorMessage = message;
            _messageType = MessageType.success;
          });
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString().replaceAll("Exception: ", "");
            _messageType = MessageType.error;
          });
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập họ và tên.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập email.';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Định dạng email không hợp lệ.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số điện thoại.';
    }
    final phoneRegex = RegExp(r'^(0[3|5|7|8|9])+([0-9]{8})$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Số điện thoại không hợp lệ.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu.';
    }
    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu.';
    }
    if (value != _passwordController.text) {
      return 'Mật khẩu xác nhận không khớp.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.primaryGradient();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký'),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: gradient)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 8),
              if (_errorMessage != null)
                MessageBox(
                  title: _messageType == MessageType.success ? 'Thành công' : 'Lỗi',
                  message: _errorMessage!,
                  type: _messageType,
                  onClose: () => setState(() => _errorMessage = null),
                ),
              if (_errorMessage != null) const SizedBox(height: 12),

              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.person)),
                validator: _validateName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: _validatePassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordConfirmController,
                decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_outline)),
                obscureText: _obscurePassword,
                validator: _validateConfirmPassword,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Đăng ký', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}