import 'package:flutter/material.dart';

class LegendWidget extends StatelessWidget {
  const LegendWidget({super.key});

  Widget _buildLegendItem(Color color, String text, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          shadows: [Shadow(color: Theme.of(context).scaffoldBackgroundColor, blurRadius: 2)],
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chú giải thời tiết', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          _buildLegendItem(Color(0xFF43A047), 'Thời tiết ổn', context),
          const SizedBox(height: 3),
          _buildLegendItem(Color(0xFFFF9800), 'Thời tiết trung bình', context),
          const SizedBox(height: 3),
          _buildLegendItem(Color(0xFFFA0606), 'Thời tiết xấu', context),
        ],
      ),
    );
  }
}