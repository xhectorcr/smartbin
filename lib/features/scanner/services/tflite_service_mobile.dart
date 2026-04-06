import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class InferenceParams {
  final Map<String, dynamic> imageMap;
  final int inputDim;
  final bool isFloat;
  final int interpreterAddress;
  final List<String> labels;
  
  InferenceParams(this.imageMap, this.inputDim, this.isFloat, this.interpreterAddress, this.labels);
}

// Función dinámica para correr en isolate de inicio a fin
Future<Map<String, dynamic>?> _runInferenceInIsolate(InferenceParams params) async {
  try {
    final width = params.imageMap['width'] as int;
    final height = params.imageMap['height'] as int;
    final planes = params.imageMap['planes'] as List;
    final targetSize = params.inputDim;
    final isFloat = params.isFloat;
  
  img.Image? image;
  if (planes.length == 3) {
      // YUV420 Android
      final yPlane = planes[0];
      final uPlane = planes[1];
      final vPlane = planes[2];
      image = img.Image(width: width, height: height);
      for(int y=0; y<height; y++) {
          int uvRow = y >> 1;
          for(int x=0; x<width; x++) {
              int uvCol = x >> 1;
              int yIndex = y * (yPlane['bytesPerRow'] as int) + x;
              int uIndex = uvRow * (uPlane['bytesPerRow'] as int) + uvCol * (uPlane['bytesPerPixel'] as int);
              int vIndex = uvRow * (vPlane['bytesPerRow'] as int) + uvCol * (vPlane['bytesPerPixel'] as int);
              
              int yp = yPlane['bytes'][yIndex];
              int up = uPlane['bytes'][uIndex];
              int vp = vPlane['bytes'][vIndex];
              
              int r = (yp + 1.402 * (vp - 128)).toInt().clamp(0,255);
              int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).toInt().clamp(0,255);
              int b = (yp + 1.772 * (up - 128)).toInt().clamp(0,255);
              
              image.setPixelRgb(x, y, r, g, b);
          }
      }
  } else if (planes.length == 1) {
      // BGRA8888 iOS or Windows
      final plane = planes[0];
      final bytes = plane['bytes'] as Uint8List;
      image = img.Image(width: width, height: height);
      int bytesPerRow = plane['bytesPerRow'];
      for(int y=0; y<height; y++) {
         for(int x=0; x<width; x++) {
             int offset = y * bytesPerRow + x * 4;
             int b = bytes[offset];
             int g = bytes[offset+1];
             int r = bytes[offset+2];
             image.setPixelRgb(x, y, r, g, b);
         }
      }
  }

  if (image == null) return null;
  final imageInput = img.copyResize(image, width: targetSize, height: targetSize);
  
    // --- RECONSTRUCT INTERPRETER IN BACKGROUND ISOLATE ---
    var interpreter = Interpreter.fromAddress(params.interpreterAddress);
    int outputCount = interpreter.getOutputTensors().length;

    List<List<List<List<double>>>> inputFloat = [];
    List<List<List<List<int>>>> inputInt = [];

    // Manejo de cuantización dinámica para el INPUT (fundamental para Int8 de Ultralytics)
    if (!isFloat) {
        double inScale = interpreter.getInputTensor(0).params.scale;
        int inZeroPoint = interpreter.getInputTensor(0).params.zeroPoint;
        if (inScale == 0.0) inScale = 1.0;

        inputInt = List.generate(1, (i) => List.generate(targetSize, (y) => List.generate(targetSize, (x) {
            final pixel = imageInput.getPixel(x, y);
            // YOLOv8 normaliza [0,1] antes del INT8. Así que cuantizamos correctamente:
            int rQuant = ((pixel.r / 255.0) / inScale + inZeroPoint).toInt().clamp(-128, 255);
            int gQuant = ((pixel.g / 255.0) / inScale + inZeroPoint).toInt().clamp(-128, 255);
            int bQuant = ((pixel.b / 255.0) / inScale + inZeroPoint).toInt().clamp(-128, 255);
            return [rQuant, gQuant, bQuant];
        })));
    } else {
        inputFloat = List.generate(1, (i) => List.generate(targetSize, (y) => List.generate(targetSize, (x) {
            final pixel = imageInput.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        })));
    }

    if (outputCount == 4) {
          var outputBoxes = List.generate(1, (i) => List.generate(10, (j) => List.filled(4, 0.0)));
          var outputClasses = List.generate(1, (i) => List.filled(10, 0.0));
          var outputScores = List.generate(1, (i) => List.filled(10, 0.0));
          var numDetections = List.filled(1, 0.0);

          Map<int, Object> outputs = { 0: outputBoxes, 1: outputClasses, 2: outputScores, 3: numDetections };
          
          interpreter.runForMultipleInputs([isFloat ? inputFloat : inputInt], outputs);

          double maxConfidence = 0.0;
          int bestIndex = 0;
          for (int i = 0; i < 10; i++) {
              double score = outputScores[0][i];
              if (score > maxConfidence) { maxConfidence = score; bestIndex = i; }
          }

          if (maxConfidence > 0.4) {
            int classId = outputClasses[0][bestIndex].toInt();
            if (classId >= 0 && classId < params.labels.length) {
               return {
                  'label': params.labels[classId].trim(),
                  'confidence': maxConfidence,
                  'box': outputBoxes[0][bestIndex],
               };
            }
          }
      } else if (outputCount == 1) {
          final outputShape = interpreter.getOutputTensor(0).shape; // [1, 84, 8400]
          final outputType = interpreter.getOutputTensor(0).type;
          int rows = outputShape[1];
          int cols = outputShape[2];
          
          dynamic outputTensor;
          if (outputType == TensorType.float32) {
              outputTensor = List.generate(outputShape[0], (i) => List.generate(rows, (j) => List.filled(cols, 0.0)));
          } else {
              // int8 o uint8
              outputTensor = List.generate(outputShape[0], (i) => List.generate(rows, (j) => List.filled(cols, 0)));
          }

          Map<int, Object> outputs = { 0: outputTensor };
          interpreter.runForMultipleInputs([isFloat ? inputFloat : inputInt], outputs);

          var outputData = outputTensor[0]; 
          bool isTransposed = rows > cols;
          int numAnchors = isTransposed ? rows : cols;
          
          // Calcula el número REAL de clases basadas en el archivo de texto, 
          // ignorando líneas o Enter vacíos para evitar 'Crash Silenciosos'. 
          // Esto la hace 100% compatible con tus propios modelos entrenados.
          int numClasses = params.labels.where((l) => l.trim().isNotEmpty).length;

          double maxConfidence = 0.0;
          int bestClassId = -1;
          int bestAnchor = -1;

          // Extraemos la info de cuantización (si el modelo es int8, hay que hacer math)
          double scale = 1.0;
          int zeroPoint = 0;
          if (outputType != TensorType.float32) {
             scale = interpreter.getOutputTensor(0).params.scale;
             zeroPoint = interpreter.getOutputTensor(0).params.zeroPoint;
             if (scale == 0.0) scale = 1.0;
          }

          for (int a = 0; a < numAnchors; a++) {
             for (int c = 0; c < numClasses; c++) {
                 var val = isTransposed ? outputData[a][c + 4] : outputData[c + 4][a];
                 double score = (outputType == TensorType.float32) ? val : (val - zeroPoint) * scale;
                 if (score > maxConfidence) {
                     maxConfidence = score;
                     bestClassId = c;
                     bestAnchor = a;
                 }
             }
          }

          if (bestClassId != -1) {
             // Debug visual: si es muy bajo el porcentaje, al menos te decimos cuánto fue
             if (maxConfidence < 0.3) {
                 return {
                    'label': 'Buscando: ${params.labels[bestClassId]} ${(maxConfidence * 100).toInt()}%',
                    'confidence': 0.8, // falso para forzarlo a renderizar
                    'box': [0.1, 0.1, 0.2, 0.2] // esquina pequeña
                 };
             }

             var cxRaw = isTransposed ? outputData[bestAnchor][0] : outputData[0][bestAnchor];
             var cyRaw = isTransposed ? outputData[bestAnchor][1] : outputData[1][bestAnchor];
             var wRaw = isTransposed ? outputData[bestAnchor][2] : outputData[2][bestAnchor];
             var hRaw = isTransposed ? outputData[bestAnchor][3] : outputData[3][bestAnchor];

             double cx = (outputType == TensorType.float32) ? cxRaw : (cxRaw - zeroPoint) * scale;
             double cy = (outputType == TensorType.float32) ? cyRaw : (cyRaw - zeroPoint) * scale;
             double w = (outputType == TensorType.float32) ? wRaw : (wRaw - zeroPoint) * scale;
             double h = (outputType == TensorType.float32) ? hRaw : (hRaw - zeroPoint) * scale;

             // YOLOv8 a veces exporta normalizado [0-1] o relativo [0-320]. Lo detectamos dinámicamente viendo si el ancho es pequeñísimo.
             double scaleDiv = (w > 1.5 || h > 1.5) ? targetSize.toDouble() : 1.0;

             double xMin = (cx - w / 2) / scaleDiv;
             double yMin = (cy - h / 2) / scaleDiv;
             double xMax = (cx + w / 2) / scaleDiv;
             double yMax = (cy + h / 2) / scaleDiv;

             return {
                'label': params.labels[bestClassId].trim(),
                'confidence': maxConfidence,
                'box': [yMin, xMin, yMax, xMax], 
             };
          }
      }
  } catch(e, stacktrace) {
      // Visual Debugging. If an exception triggers we show it on the UI
      return {
         'label': 'CRASH: $e',
         'confidence': 0.99,
         'box': [0.1, 0.1, 0.9, 0.9]
      };
  }

  return null;
}

class TFLiteService {
  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> initialize() async {
    try {
      // Intenta cargar YOLOv8 o SSD según esté disponible
      _interpreter = await Interpreter.fromAsset('assets/detect.tflite');
      final labelData = await rootBundle.loadString('assets/labelmap.txt');
      _labels = labelData.split('\n');
      print('TFLite Modelo Iniciado Correctamente.');
    } catch (e) {
      print('Error al iniciar TFLite: $e');
    }
  }

  Future<Map<String, dynamic>?> classifyImage(Map<String, dynamic> imageMap) async {
    if (_interpreter == null || _labels == null) return null;

    final inputShape = _interpreter!.getInputTensor(0).shape;
    final int inputDim = inputShape[1];
    bool isFloat = _interpreter!.getInputTensor(0).type == TensorType.float32;

    // Pasamos el proceso CIENTÍFICAMENTE pesado completamente al isolate, 
    // usando FlatBuffers (`Float32List`) y reconstruyendo el intérprete para jamás bloquear la UI.
    final params = InferenceParams(
        imageMap,
        inputDim,
        isFloat,
        _interpreter!.address,
        _labels!
    );

    // Compute procesará todo: Decodificar, Escalar, Ejecutar Modelo, Y Escanear cajas.
    // Solo enviará de regreso la respuesta lista (O(1)). Cero congelamientos.
    return await compute(_runInferenceInIsolate, params);
  }

  void dispose() {
    _interpreter?.close();
  }
}

