import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CameraPlaceholder extends StatelessWidget {
  const CameraPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated camera feed background
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?q=80&w=2070&auto=format&fit=crop',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF2C2C2C),
                child: const Icon(
                  Icons.camera_alt,
                  size: 100,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
          // Dark gradient over the camera feed for better text visibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
