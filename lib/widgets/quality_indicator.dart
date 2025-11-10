import 'package:flutter/material.dart';
import '../utils/constants.dart';

class QualityIndicator extends StatelessWidget {
  final int percent;
  const QualityIndicator({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$percent%',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: AppColors.ring.withOpacity(0.6)),
                  FractionallySizedBox(
                    widthFactor: percent.clamp(0, 100) / 100,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppGradients.bar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
