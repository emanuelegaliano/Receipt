# ONNX Runtime: la libreria nativa cerca le classi Java per nome via JNI
# (es. ai.onnxruntime.OnnxTensor). Se R8 le rinomina o le toglie, la prima
# inferenza in release va in crash con "JNI DETECTED ERROR: java_class == null".
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
