# TFLite Models

Place the trained TFLite models in this directory.

## Model Versions

- **cortex_v1.tflite** - Initial base model
- **cortex_v2.tflite** - Updated model after first training cycle

## Downloading Models

Models will be automatically downloaded from the server when updates are available.

For manual deployment, place the `.tflite` file here and update the model path in `feature_extractor.dart`.

## Model Specifications

- **Input Shape**: [1, 200] (Float32)
- **Output Shape**: [1, 64] (Float32, L2-normalized)
- **Quantization**: Float16 for mobile optimization
- **Size**: ~50-100 KB
