import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/scanner_state.dart';

class ScannerOverlay extends StatefulWidget {
  final StatusType status;
  final Rect? boundingBox; // Recibe la caja de la UI

  const ScannerOverlay({Key? key, required this.status, this.boundingBox}) : super(key: key);

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> {
  Color _getColorForStatus() {
    switch (widget.status) {
      case StatusType.scanning:
        return AppColors.scanning;
      case StatusType.correct:
        return AppColors.correct;
      case StatusType.incorrect:
        return AppColors.incorrect;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameColor = _getColorForStatus();
    
    return Stack(
      children: [
        // Dibuja el cuadro que sigue al objeto usando CustomPaint!
        if (widget.boundingBox != null)
          Positioned.fill(
             child: CustomPaint(
               painter: BoundingBoxPainter(
                 rect: widget.boundingBox!,
                 color: frameColor,
               ),
             ),
          ),

        // Top App Bar like area
        Positioned(
          top: 50,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SmartBin',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              // Quitado el botón de flash
              const SizedBox.shrink(),
            ],
          ),
        ),
        

      ],
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final Rect rect;
  final Color color;

  BoundingBoxPainter({required this.rect, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Background highlight
    final bgPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // Escalar la caja normalizada a las dimensiones reales de la pantalla
    Rect scaledRect = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );

    // Pintar el rectángulo que enmarca al objeto
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(12)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(12)),
      paint,
    );
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.color != color;
  }
}

