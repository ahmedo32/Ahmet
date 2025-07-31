import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../pages/crop_page.dart';  // make sure this import is here

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source);
    if (!mounted || picked == null) return;

    // 1) Wrap picked image in a File
    final File rawFile = File(picked.path);

    // 2) Open the crop UI
    final File? croppedFile = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => CropPage(image: rawFile),
      ),
    );

    // 3) If the user actually cropped, go to your OCR/ResultPage
    if (croppedFile != null) {
      Navigator.pushNamed(
        context,
        '/result',
        arguments: croppedFile,
      );
    }
    // else: they cancelled the crop dialog, do nothing (stay here)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick or Take a Photo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: const Text('Pick from Gallery'),
            ),
          ],
        ),
      ),
    );
  }
}
// Ensure that the CropPage is imported correctly to avoid any issues with navigation.
// The CropPage should handle the cropping logic and return the cropped file back to this page.