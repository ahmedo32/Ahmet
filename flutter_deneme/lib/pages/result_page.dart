import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart' as ml_kit;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ocr_result.dart';
import '../services/pdf_service.dart';
import '../services/db_helper.dart';
import '../pages/crop_page.dart';
import '../services/ocr_client.dart';

/// Data holder for a page's OCR text and metadata
class PageData {
  final String text;
  final String? lectureCode;
  final String? note;
  final List<String>? tags;
  PageData({required this.text, this.lectureCode, this.note, this.tags});
}

/// Result of the "Save Page" dialog: page data + whether to close
class SavePageResult {
  final PageData page;
  final bool close;
  SavePageResult(this.page, this.close);
}

/// Dialog for editing OCR text and metadata
class SavePageDialog extends StatelessWidget {
  final String initialText;
  const SavePageDialog({super.key, required this.initialText});

  @override
  Widget build(BuildContext context) {
    final textCtrl = TextEditingController(text: initialText);
    final lectureCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return AlertDialog(
      title: const Text('Save Page'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: textCtrl,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'OCR Text'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: lectureCtrl,
                decoration: const InputDecoration(labelText: 'Lecture Code'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: tagsCtrl,
                decoration: const InputDecoration(labelText: 'Tags (comma-separated)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final page = PageData(
                text: textCtrl.text.trim(),
                lectureCode: lectureCtrl.text.trim().isEmpty ? null : lectureCtrl.text.trim(),
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                tags: tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
              );
              Navigator.pop(context, SavePageResult(page, false));
            }
          },
          child: const Text('Add Page'),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final page = PageData(
                text: textCtrl.text.trim(),
                lectureCode: lectureCtrl.text.trim().isEmpty ? null : lectureCtrl.text.trim(),
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                tags: tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
              );
              Navigator.pop(context, SavePageResult(page, true));
            }
          },
          child: const Text('Save & Close'),
        ),
      ],
    );
  }
}

/// Top action bar with image editing, text editing, and document sharing
class ActionBar extends StatelessWidget {
  final VoidCallback onEditImage;
  final VoidCallback onEditText;
  final VoidCallback onShareDocument;

  const ActionBar({
    super.key,
    required this.onEditImage,
    required this.onEditText,
    required this.onShareDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: onEditImage,
          icon: const Icon(Icons.crop),
          label: const Text('Edit Image'),
        ),
        ElevatedButton.icon(
          onPressed: onEditText,
          icon: const Icon(Icons.edit),
          label: const Text('Edit Text/Save'),
        ),
        ElevatedButton.icon(
          onPressed: onShareDocument,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Share Document'),
        ),
      ],
    );
  }
}

/// Main OCR result page with multi-page support
class ResultPage extends StatefulWidget {
  const ResultPage({super.key});
  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  final _picker = ImagePicker();
  File? _image;
  String _ocrText = '';
  bool _loading = true;
  bool _isShowingDialog = false;
  bool _ocrStarted = false;
  final List<String> _pages = [];
  int _ocrFailureCount = 0;
  final int _maxOcrFailures = 3;
  double _textScale = 1.0;
  bool _scaleLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scaleLoaded) {
      _scaleLoaded = true;
      SharedPreferences.getInstance().then((prefs) {
        final v = prefs.getDouble('textScaleFactor') ?? 1.0;
        setState(() => _textScale = v);
      });
      final args = ModalRoute.of(context)?.settings.arguments;
      if (!_ocrStarted && args is File) {
        _image = args;
        _ocrStarted = true;
        _performOCR();
      } else if (!_ocrStarted) {
        setState(() { _ocrText = 'No image provided'; _loading = false; });
        _ocrStarted = true;
      }
    }
  }

  Future<void> _performOCR() async {
    if (_image == null) return;
    setState(() { _loading = true; });

    try {
      // Call OCR backend first
      final bytes = await _image!.readAsBytes();
      String recognizedText = await OCRClient().extractText(bytes);

      // Fallback to on-device if empty
      if (recognizedText.isEmpty || recognizedText.length < 5) {
        final input = ml_kit.InputImage.fromFile(_image!);
        final textRec = ml_kit.GoogleMlKit.vision.textRecognizer();
        final textRes = await textRec.processImage(input);
        await textRec.close();
        recognizedText = textRes.text.trim();
      }

      // Enhance handwriting results
      final processed = _enhanceHandwritingRecognition(recognizedText);

      setState(() {
        _ocrText = processed;
        _loading = false;
      });
      _ocrFailureCount = 0;
      await _showSavePageDialog();

    } catch (e) {
      _ocrFailureCount++;
      setState(() {
        _ocrText = 'OCR failed (attempt $_ocrFailureCount of $_maxOcrFailures)';
        _loading = false;
      });
      if (_ocrFailureCount < _maxOcrFailures) {
        _showRetryDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum OCR attempts reached. Please try with a different image.'))
        );
        _ocrFailureCount = 0;
      }
    }
  }

  Future<void> _cropImage() async {
    final File? cropped = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => CropPage(image: _image!)),
    );
    if (cropped != null) {
      setState(() {
        _image = cropped;
        _loading = true;
      });
      await _performOCR();
    }
  }

  Future<void> _showSavePageDialog() async {
    final result = await showDialog<SavePageResult>(
      context: context,
      builder: (_) => SavePageDialog(initialText: _ocrText),
    );
    if (result == null) return;

    if (result.close) {
      final now = DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now());
      for (var pageText in _pages) {
        await DBHelper.insertResult(OCRResult(
          imagePath:   _image!.path,
          text:        pageText,
          timestamp:   now,
          lectureCode: result.page.lectureCode,
          note:        result.page.note,
          tags:        result.page.tags,
        ));
      }
      await DBHelper.insertResult(OCRResult(
        imagePath:   _image!.path,
        text:        result.page.text,
        timestamp:   now,
        lectureCode: result.page.lectureCode,
        note:        result.page.note,
        tags:        result.page.tags,
      ));
      _pages.clear();
      Navigator.pop(context);
    } else {
      setState(() => _pages.add(result.page.text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Page added (total: ${_pages.length})'))
      );
      final XFile? next = await _picker.pickImage(source: ImageSource.camera);
      if (!mounted || next == null) return;
      setState(() {
        _image = File(next.path);
        _loading = true;
      });
      await _performOCR();
    }
  }

  Future<void> _shareDocument() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('No pages to share.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final exportedPdf = await PdfService.buildDocument(_pages);
      final prefs = await SharedPreferences.getInstance();
      final loc = SaveLocation.values[prefs.getInt('saveLocation') ?? 0];
      final dir = (loc == SaveLocation.documents)
        ? await getApplicationDocumentsDirectory()
        : await getTemporaryDirectory();
      final filename = exportedPdf.path.split(Platform.pathSeparator).last;
      final baseName = filename.split('.').first;
      final filesToShare = Directory(dir.path)
        .listSync()
        .where((f) {
          final name = f.path.split(Platform.pathSeparator).last;
          return name.startsWith(baseName) && (name.endsWith('.pdf') || name.endsWith('.txt'));
        })
        .map((f) => XFile(f.path))
        .toList();
      await Share.shareXFiles(filesToShare, text: 'OCR Document');
      setState(() => _pages.clear());
    } catch (e) {
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Share failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showRetryDialog() {
    if (_isShowingDialog) return;
    _isShowingDialog = true;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('OCR Failed'),
        content: const Text('Retry OCR?'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _isShowingDialog = false; },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _isShowingDialog = false; _performOCR(); },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _enhanceHandwritingRecognition(String text) {
    if (text.isEmpty) return text;
    String enhanced = text;
    final substitutions = {
      r'(?<=[a-zA-Z])0(?=[a-zA-Z])': 'o',
      r'(?<=[a-zA-Z])1(?=[a-zA-Z])': 'l',
      r'(?<=[a-zA-Z])5(?=[a-zA-Z])': 's',
      r'(?<=[a-zA-Z])8(?=[a-zA-Z])': 'B',
      r'(?<=[a-zA-Z])6(?=[a-zA-Z])': 'G',
      r'\brn\b': 'm',
      r'\bm\b(?=\s+[a-z])': 'in',
      r'\bu\b(?=\s+[a-z])': 'a',
      r'(?<=\s)tl1e\b': 'the',
      r'(?<=\s)ancl\b': 'and',
      r'(?<=\s)wlth\b': 'with',
      r'([a-z])([A-Z])': r'\1 \2',
      r'\.(\w)': r'. \1',
      r'(\w)\.': r'\1. ',
    };
    for (var entry in substitutions.entries) {
      enhanced = enhanced.replaceAll(RegExp(entry.key), entry.value);
    }
    enhanced = enhanced.replaceAll(RegExp(r'\s+'), ' ').trim();
    enhanced = enhanced.replaceAll(RegExp(r'\s+([,.!?])'), r'\1');
    enhanced = enhanced.replaceAllMapped(
      RegExp(r'([.!?])\s*([a-z])'),
      (m) => '${m.group(1)} ${m.group(2)!.toUpperCase()}'
    );
    return enhanced;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR Result')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_image != null) Image.file(_image!),
                const SizedBox(height: 12),
                ActionBar(
                  onEditImage: _cropImage,
                  onEditText: _showSavePageDialog,
                  onShareDocument: _shareDocument,
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _ocrText,
                      textScaler: TextScaler.linear(_textScale),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}