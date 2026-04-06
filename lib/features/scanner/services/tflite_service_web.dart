import 'dart:typed_data';
import 'package:image/image.dart' as img;

class TFLiteService {
  Future<void> initialize() async {
    print('TFLite no tiene bindings en la Web a través de tflite_flutter.');
    print('Se configuró un mock temporal en Web para evitar que la aplicación crashee.');
  }

  Future<Map<String, dynamic>?> classifyImage(Map<String, dynamic> imageMap) async {
    // Mock web result testing
    return {
      'label': 'bottle',
      'confidence': 0.95,
      'box': [0.2, 0.2, 0.8, 0.8],
    };
  }

  void dispose() {}
}
