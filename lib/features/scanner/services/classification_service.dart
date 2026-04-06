import 'dart:async';
import 'package:flutter/material.dart'; // Para pintar Rect y cajas
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'tflite_service.dart';

class ClassificationResult {
  final String? detectedObject;
  final String? detectedColor;
  final String? expectedColor;
  final bool isCorrect;
  final Rect? objectBoundingBox; // Nuevo parámetro para rastrear en pantalla

  ClassificationResult({
    this.detectedObject,
    this.detectedColor,
    this.expectedColor,
    required this.isCorrect,
    this.objectBoundingBox,
  });
}

class ClassificationService {
  final TFLiteService _tfliteService = TFLiteService();
  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      await _tfliteService.initialize();
      _initialized = true;
    }
  }

  // --- Norma Peruana mapeada a clases de COCO Dataset ---
  Map<String, String> get rules => _rules;
  
  final Map<String, String> _rules = {
    // Blanco: Plásticos
    'bottle': 'blanco', // Botella Genérica
    'plastico': 'blanco', // MODELO NUEVO
    
    // Amarillo: Metales
    'fork': 'amarillo',
    'metales': 'amarillo', // MODELO NUEVO
    
    // Azul: Papel y cartón
    'book': 'azul',     // Libro Genérico
    'papel_carton': 'azul', // MODELO NUEVO
    
    // Gris: Vidrio
    'wine glass': 'gris', // Genérico
    'vidrio': 'gris', // MODELO NUEVO
    
    // Negro: Basura / No aprovechable
    'teddy bear': 'negro', // Genérico
    'noaprovechables': 'negro', // MODELO NUEVO
    
    // Genéricos Marrones por compatibilidad
    'apple': 'marron',
    'banana': 'marron',
  };

  final Map<String, String> _translations = {
    'bottle': 'botella',
    'cup': 'vaso',
    'fork': 'tenedor',
    'spoon': 'cuchara',
    'knife': 'cuchillo',
    'book': 'libro',
    'paper': 'papel',
    'apple': 'manzana',
    'banana': 'plátano',
    'orange': 'naranja',
    'carrot': 'zanahoria',
    'broccoli': 'brócoli',
    'wine glass': 'copa de vino',
    'cell phone': 'celular',
    'laptop': 'laptop',
    'tv': 'televisor',
    'mouse': 'mouse',
    'keyboard': 'teclado',
    'teddy bear': 'oso de peluche',
    
    // Traducciones de TU MODELO PROPIO
    'papel_carton': 'papel o cartón',
    'plastico': 'plástico',
    'vidrio': 'vidrio',
    'metales': 'metal',
    'noaprovechables': 'residuo no aprovechable'
  };

  /// Procesa el frame de la cámara, detecta el objeto y valida.
  Future<ClassificationResult?> processFrame(CameraImage image) async {
    try {
      await init();
      // 1. PASO IA (TFLite Objetos + Bounding Box):
      final map = await _runTFLiteObjectDetection(image);
      if (map == null) return null; // No hay objetos de interés

      final String object = map['label'];
      final List<dynamic>? boxArray = map['box']; 
      
      final String objectEs = _translations[object] ?? object;

      // Obtener Tacho esperado (si es null, no es reciclable o no está en regla)
      final expected = _rules[object];
      
      final isCorrect = expected != null;

      // Ajustamos el bounding box a coordenadas de pantalla (ejemplo heurístico)
      // Como YOLO evalúa imagen en landscape pero dibujamos en portrait,
      // las "X" de Yolo son "Y" en pantalla, y las "Y" de Yolo son "X".
      Rect? bbox;
      if (boxArray != null) {
         double yMinNorm = boxArray[0]; // 0.0 a 1.0
         double xMinNorm = boxArray[1];
         double yMaxNorm = boxArray[2];
         double xMaxNorm = boxArray[3];
         
         // Para compensar la rotación de 90° de la cámara de Android nativa.
         // El sensor lee en formato 'Landscape', por lo que debemos cruzar los ejes.
         // x de pantalla = y de yolo
         // y de pantalla = compensamos invirtiendo el x de yolo
         double screenXMin = yMinNorm;
         double screenYMin = 1.0 - xMaxNorm;
         double screenXMax = yMaxNorm;
         double screenYMax = 1.0 - xMinNorm;

         // Devolvemos el normalizado (0 a 1) para que el CustomPainter resuelva su tamaño asegurándonos de que Min no sea > Max
         bbox = Rect.fromLTRB(
           screenXMin < screenXMax ? screenXMin : screenXMax, 
           screenYMin < screenYMax ? screenYMin : screenYMax, 
           screenXMax > screenXMin ? screenXMax : screenXMin, 
           screenYMax > screenYMin ? screenYMax : screenYMin
         );
      }

      return ClassificationResult(
        detectedObject: objectEs,
        detectedColor: null, 
        expectedColor: expected ?? 'No Clasificado',
        isCorrect: isCorrect,
        objectBoundingBox: bbox, 
      );
    } catch (e) {
      print('Error procesando imagen: $e');
      return null;
    }
  }

  // --- MÉTODOS PRIVADOS ---

  Future<Map<String, dynamic>?> _runTFLiteObjectDetection(CameraImage image) async {
    final Map<String, dynamic> parsedImage = {
      'width': image.width,
      'height': image.height,
      'planes': image.planes.map((p) => {
        'bytes': p.bytes,
        'bytesPerRow': p.bytesPerRow,
        'bytesPerPixel': p.bytesPerPixel,
      }).toList(),
    };
    final result = await _tfliteService.classifyImage(parsedImage);
    return result;
  }

  Future<String> _runColorDetection(XFile file) async {
    // MOCK: Filtramos el amarillo momentaneamente 
    await Future.delayed(const Duration(milliseconds: 100));
    return 'azul'; // Asume que siempre el tacho es azul por ahora 
  }
}
