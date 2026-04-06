import 'dart:typed_data';
import 'package:image/image.dart' as img;

class TFLiteService {
  Future<void> initialize() async {
    throw UnsupportedError('TFLiteService is not supported on this platform.');
  }

  Future<Map<String, dynamic>?> classifyImage(Map<String, dynamic> imageMap) async {
    throw UnsupportedError('TFLiteService is not supported on this platform.');
  }

  void dispose() {}
}
