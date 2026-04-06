import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/theme/app_colors.dart';

class CameraFeed extends StatefulWidget {
  final Future<void> Function(CameraImage)? onImageCaptured;

  const CameraFeed({Key? key, this.onImageCaptured}) : super(key: key);

  @override
  State<CameraFeed> createState() => _CameraFeedState();
}

class _CameraFeedState extends State<CameraFeed> {
  CameraController? _controller;
  bool _isInitialized = false;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras found.');
        return;
      }
      
      _controller = CameraController(
        cameras.first, 
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Loop en tiempo real (Stream) sin usar temporizadores bloqueantes
        if (widget.onImageCaptured != null) {
          bool isProcessing = false;
          _controller!.startImageStream((CameraImage image) async {
            if (!isProcessing && _isInitialized) {
              isProcessing = true;
              try {
                await widget.onImageCaptured!(image);
              } catch (e) {
                debugPrint("Error procesando frame: $e");
              } finally {
                isProcessing = false;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: AppColors.background,
        width: double.infinity,
        height: double.infinity,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    return Container(
      color: AppColors.background,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Default Camera Preview (No aggressive zoom or artificial cropping)
          Center(
            child: CameraPreview(_controller!),
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
