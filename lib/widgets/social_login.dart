import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialLoginButtons extends StatelessWidget {
  final VoidCallback? onGoogleSignIn;
  final VoidCallback? onFacebookSignIn;

  const SocialLoginButtons({
    super.key,
    this.onGoogleSignIn,
    this.onFacebookSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider(thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Hoặc tiếp tục với Google',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            const Expanded(child: Divider(thickness: 1)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(
              onPressed: onGoogleSignIn,
              child: Image.asset(
                'assets/icons/google.png',
                height: 30,
                width: 30,
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required Widget child,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: child,
      ),
    );
  }
}