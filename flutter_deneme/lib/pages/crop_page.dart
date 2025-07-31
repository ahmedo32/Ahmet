import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crop_your_image/crop_your_image.dart';

/// Must match the enum order in SettingsPage:
enum CropAspectRatio { free, square, ratio4_3, ratio16_9 }

double? _mapAspectRatio(CropAspectRatio ar) {
  switch (ar) {
    case CropAspectRatio.square:
      return 1.0;
    case CropAspectRatio.ratio4_3:
      return 4 / 3;
    case CropAspectRatio.ratio16_9:
      return 16 / 9;
    case CropAspectRatio.free:
      return null;
  }
}

class CropPage extends StatefulWidget {
  final File image;
  const CropPage({super.key, required this.image});

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  final CropController _controller = CropController();
  Uint8List? _originalImage;

  // NEW: store user preference
  CropAspectRatio _aspectRatio = CropAspectRatio.free;

  @override
  void initState() {
    super.initState();
    _loadImageBytes();
    _loadAspectRatioPref();
  }

  Future<void> _loadImageBytes() async {
    final bytes = await widget.image.readAsBytes();
    setState(() => _originalImage = bytes);
  }

  /// NEW: load the saved index and map to enum
  Future<void> _loadAspectRatioPref() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('cropAspectRatio') ?? 0;
    if (idx >= 0 && idx < CropAspectRatio.values.length) {
      setState(() => _aspectRatio = CropAspectRatio.values[idx]);
    }
  }

  Future<File> _saveCropped(Uint8List data) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path);
    await file.writeAsBytes(data);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    if (_originalImage == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // compute the aspect ratio (null = free)
    final aspect = _mapAspectRatio(_aspectRatio);

    return Scaffold(
      appBar: AppBar(title: const Text("Crop Image")),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              controller: _controller,
              image: _originalImage!,
              withCircleUi: false,
              aspectRatio: aspect,              // ← apply here
              onCropped: (result) async {
                if (result is CropSuccess) {
                  final bytes = result.croppedImage;
                  final file = await _saveCropped(bytes);
                  if (!context.mounted) return;
                  Navigator.pop(context, file);
                } else if (result is CropFailure) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Crop failed: ${result.cause}')),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => _controller.crop(),
              child: const Text("Crop & Continue"),
            ),
          ),
        ],
      ),
    );
  }
}
