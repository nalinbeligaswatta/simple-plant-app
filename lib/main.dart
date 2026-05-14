import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Disease Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ── Labels ──────────────────────────────────────────────────────────────────
const List<String> _labels = [
  'corn_blight',
  'corn_common_rust',
  'corn_gray_leaf_spot',
  'corn_healthy',
  'tomato_bacterial_spot',
  'tomato_early_blight',
  'tomato_late_blight',
  'tomato_leaf_mold',
  'tomato_septoria_leaf_spot',
  'tomato_spider_mites',
  'tomato_target_spot',
  'tomato_yellow_leaf_curl_virus',
  'tomato_mosaic_virus',
  'tomato_healthy',
  'tomato_powdery_mildew',
  'rice_bacterial_leaf_blight',
  'rice_brown_spot',
  'rice_healthy',
  'rice_leaf_blast',
  'rice_leaf_scald',
  'rice_sheath_blight',
  'coconut_healthy',
  'coconut_pest_damage',
  'coconut_yellowing',
  'coconut_leaf_spot',
];

String _formatLabel(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

bool _isHealthy(String label) => label.contains('healthy');

// ── Home Page ────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  String? _result;
  double? _confidence;
  bool _loading = false;
  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model/model.tflite');
    } catch (e) {
      debugPrint('Model load error: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _result = null;
      _confidence = null;
      _loading = true;
    });

    await _classify(File(picked.path));
  }

  Future<void> _classify(File file) async {
    if (_interpreter == null) {
      setState(() {
        _result = 'Model not loaded';
        _loading = false;
      });
      return;
    }

    try {
      // Read and resize image to 224x224
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image');
      final resized = img.copyResize(decoded, width: 224, height: 224);

      // Build input tensor [1, 224, 224, 3] normalized to [0,1]
      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
            },
          ),
        ),
      );

      // Output tensor [1, 25]
      final output = List.generate(1, (_) => List.filled(25, 0.0));

      _interpreter!.run(input, output);

      final scores = output[0];
      int maxIndex = 0;
      double maxScore = scores[0];
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIndex = i;
        }
      }

      setState(() {
        _result = _labels[maxIndex];
        _confidence = maxScore;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF2E7D32);
    final healthy = _result != null && _isHealthy(_result!);
    final resultColor = _result == null
        ? green
        : healthy
            ? const Color(0xFF2E7D32)
            : const Color(0xFFC62828);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: green,
        title: const Text(
          '🌿 Plant Disease Detector',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Image Box ──────────────────────────────
            GestureDetector(
              onTap: () => _showPicker(context),
              child: Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: green.withOpacity(0.4), width: 2),
                ),
                child: _image == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              size: 64, color: green.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to select a leaf image',
                            style: TextStyle(
                                color: green.withOpacity(0.7), fontSize: 16),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_image!, fit: BoxFit.cover,
                            width: double.infinity),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Buttons ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: green,
                      side: BorderSide(color: green),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Result ─────────────────────────────────
            if (_loading)
              const CircularProgressIndicator()
            else if (_result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: resultColor.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Icon(
                      healthy
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      color: resultColor,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatLabel(_result!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                    if (_confidence != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 14,
                            color: resultColor.withOpacity(0.8)),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}
