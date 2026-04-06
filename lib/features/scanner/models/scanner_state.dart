import 'package:flutter/material.dart';

enum StatusType {
  scanning,
  correct,
  incorrect,
}

class ScannerState {
  final StatusType status;
  final String message;
  final String subMessage;
  final String? detectedObject;
  final String? detectedBinColor;
  final String? expectedBinColor;
  final Rect? boundingBox;

  const ScannerState({
    required this.status,
    required this.message,
    required this.subMessage,
    this.detectedObject,
    this.detectedBinColor,
    this.expectedBinColor,
    this.boundingBox,
  });
}
