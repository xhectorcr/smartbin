import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/scanner_state.dart';

class StatusPanel extends StatelessWidget {
  final ScannerState state;
  final VoidCallback onTapNextState;

  const StatusPanel({
    Key? key,
    required this.state,
    required this.onTapNextState,
  }) : super(key: key);

  Color _getColor() {
    switch (state.status) {
      case StatusType.scanning:
        return AppColors.scanning;
      case StatusType.correct:
        return AppColors.correct;
      case StatusType.incorrect:
        return AppColors.incorrect;
    }
  }

  IconData _getIcon() {
    switch (state.status) {
      case StatusType.scanning:
        return Icons.document_scanner;
      case StatusType.correct:
        return Icons.check_circle;
      case StatusType.incorrect:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapNextState,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getColor().withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(),
                    color: _getColor(),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.message,
                        style: TextStyle(
                          color: _getColor(),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.subMessage,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (state.detectedObject != null || state.detectedBinColor != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (state.detectedObject != null)
                              _InfoChip(
                                icon: Icons.local_drink_outlined,
                                label: 'Objeto: ${state.detectedObject}',
                              ),
                            if (state.detectedBinColor != null)
                              _InfoChip(
                                icon: Icons.delete_outline,
                                label: 'Tacho: ${state.detectedBinColor}',
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({Key? key, required this.icon, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

