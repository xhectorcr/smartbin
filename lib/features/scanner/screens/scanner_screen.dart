import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/scanner_state.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import '../services/classification_service.dart';
import '../widgets/camera_feed.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/status_panel.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ClassificationService _classificationService = ClassificationService();
  
  ScannerState _currentState = const ScannerState(
      status: StatusType.scanning,
      message: 'Analizando escena...',
      subMessage: 'Buscando el objeto y el tacho',
  );

  Future<void> _onImageCaptured(CameraImage image) async {
    final result = await _classificationService.processFrame(image);

    if (mounted) {
      if (result != null) {
        setState(() {
          _currentState = ScannerState(
            status: StatusType.correct,
            message: 'Objeto detectado: ${result.detectedObject?.toUpperCase()}',
            subMessage: 'Debería ir en el tacho color ${result.expectedColor?.toUpperCase()}',
            detectedObject: result.detectedObject,
            expectedBinColor: result.expectedColor,
            boundingBox: result.objectBoundingBox,
          );
        });
      } else {
        setState(() {
          _currentState = const ScannerState(
            status: StatusType.scanning,
            message: 'Analizando escena...',
            subMessage: 'Buscando el objeto',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Real Camera Feed con nuestro callback
          CameraFeed(
            onImageCaptured: _onImageCaptured,
          ),

          // 2. Overlay Frame (Bounding Box, Title, Actions)
          SafeArea(
            child: ScannerOverlay(
              status: _currentState.status,
              boundingBox: _currentState.boundingBox,
            ),
          ),

          // 3. Status Panel at the bottom
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: StatusPanel(
              state: _currentState,
              onTapNextState: () {
                // Force rescan on tap explicitly
                setState(() {
                   _currentState = const ScannerState(
                    status: StatusType.scanning,
                    message: 'Analizando escena...',
                    subMessage: 'Buscando el objeto y el tacho',
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

