export 'tflite_service_stub.dart'
  if (dart.library.io) 'tflite_service_mobile.dart'
  if (dart.library.html) 'tflite_service_web.dart'
  if (dart.library.js_interop) 'tflite_service_web.dart';
