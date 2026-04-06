from ultralytics import YOLO
import shutil
import os

print("Descargando y preparando YOLOv8n...")
model = YOLO('yolov8n.pt')

print("Exportando a TFLite...")
# Export model to tflite float32
model.export(format='tflite', optimize=False)

print("Moviendo a assets/detect.tflite...")
# The export command creates a directory named `yolov8n_saved_model` and puts the tflite file inside
tflite_path = 'yolov8n_saved_model/yolov8n_float32.tflite'
if os.path.exists(tflite_path):
    shutil.copy(tflite_path, 'assets/detect.tflite')
    print("¡Exito! El archivo se copió a assets/detect.tflite")
else:
    print("Error: No se encontró el archivo tflite generado en", tflite_path)
