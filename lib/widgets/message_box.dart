import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

enum MessageType { info, success, error }

class MessageBox extends StatelessWidget {
  final String title;
  final String message;
  final MessageType type;
  final VoidCallback? onClose;

  const MessageBox({
    super.key,
    required this.title,
    required this.message,
    this.type = MessageType.info,
    this.onClose,
  });

  IconData _icon() {
    switch (type) {
      case MessageType.success:
        return Icons.check_circle_outline;
      case MessageType.error:
        return Icons.error_outline;
      case MessageType.info:
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient(),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(), color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white),
              )
          ],
        ),
      ),
    );
  }
}
