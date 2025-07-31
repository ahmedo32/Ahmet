import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../services/db_helper.dart';
import '../services/pdf_service.dart';
import '../models/ocr_result.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  Future<List<OCRResult>> _ocrResults = Future.value([]);
  List<String> _lectureCodes = [];
  String? _lectureFilter;
  bool _isLoading = false;
  String _searchQuery = '';
  bool _sortDescending = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLectureCodes();
    _refreshResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLectureCodes() async {
    try {
      final codes = await DBHelper.getDistinctLectureCodes();
      setState(() {
        _lectureCodes = ['All', ...codes];
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshResults() async {
    setState(() => _isLoading = true);
    try {
      final allResults = await DBHelper.getResults();

      // Rebuild lecture‐code chips list:
      final codes = allResults
          .map((r) => r.lectureCode)
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _lectureCodes = ['All', ...codes];
      });

      // Filter by search text + chip selection:
      final filtered = allResults.where((r) {
        final textMatch = r.text
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        final lecMatch = (r.lectureCode ?? '')
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        final matchesSearch = textMatch || lecMatch;
        final matchesFilter = (_lectureFilter == null || _lectureFilter == 'All')
            ? true
            : (r.lectureCode ?? '') == _lectureFilter;
        return matchesSearch && matchesFilter;
      }).toList();

      filtered.sort((a, b) => _sortDescending
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp));

      setState(() {
        _ocrResults = Future.value(filtered);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load records: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editResult(OCRResult result) async {
    final textController = TextEditingController(text: result.text);
    final lectureController =
        TextEditingController(text: result.lectureCode ?? '');
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit OCR Record'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: textController,
                  maxLines: null,
                  decoration: const InputDecoration(labelText: 'OCR Text'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Cannot be empty' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lectureController,
                  decoration: const InputDecoration(labelText: 'Lecture Code'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isNotEmpty &&
                        !RegExp(r'^[A-Z0-9]+$').hasMatch(t)) {
                      return 'Uppercase letters & numbers only';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'text': textController.text.trim(),
                  'lectureCode': lectureController.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null &&
        (updated['text'] != result.text ||
            updated['lectureCode'] != result.lectureCode)) {
      setState(() => _isLoading = true);
      try {
        final newResult = OCRResult(
          id: result.id,
          imagePath: result.imagePath,
          text: updated['text']!,
          timestamp: result.timestamp,
          lectureCode:
              updated['lectureCode']!.isEmpty ? null : updated['lectureCode'],
        );
        await DBHelper.updateResult(newResult);
        await _refreshResults();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Record updated')));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteResult(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await DBHelper.deleteResult(id);
      await _refreshResults();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Record deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareRecord(OCRResult record) async {
    setState(() => _isLoading = true);
    try {
      // 1) Build exports (PDF/TXT/both)
      final exportedPdf = await PdfService.buildDocument([record.text]);

      // 2) Determine save location
      final prefs = await SharedPreferences.getInstance();
      final loc = SaveLocation.values[prefs.getInt('saveLocation') ?? 0];
      final dir = (loc == SaveLocation.documents)
          ? await getApplicationDocumentsDirectory()
          : await getTemporaryDirectory();

      // 3) Derive base name
      final filename = exportedPdf.path.split(Platform.pathSeparator).last;
      final baseName = filename.split('.').first;

      // 4) Collect .pdf/.txt files
      final filesToShare = Directory(dir.path)
          .listSync()
          .where((f) {
            final name = f.path.split(Platform.pathSeparator).last;
            return name.startsWith(baseName) &&
                (name.endsWith('.pdf') || name.endsWith('.txt'));
          })
          .map((f) => XFile(f.path))
          .toList();

      // 5) Share
      await Share.shareXFiles(
        filesToShare,
        text: 'OCR from ${record.timestamp}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved OCR Records')),
      body: Stack(
        children: [
          Column(
            children: [
              if (_lectureCodes.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: _lectureCodes.map((code) {
                      final isAll = code == 'All';
                      final selected = (_lectureFilter ?? 'All') == code;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(code),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _lectureFilter = isAll ? null : code;
                            });
                            _refreshResults();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search text or lecture…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                    _refreshResults();
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _refreshResults();
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                      ),
                      tooltip: _sortDescending ? 'Newest First' : 'Oldest First',
                      onPressed: () {
                        setState(() {
                          _sortDescending = !_sortDescending;
                        });
                        _refreshResults();
                      },
                    ),
                  ],
                ),
              ),

              Expanded(
                child: FutureBuilder<List<OCRResult>>(
                  future: _ocrResults,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No OCR records found.'));
                    }
                    final results = snapshot.data!;
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final r = results[index];
                        final displayLecture = r.lectureCode?.isNotEmpty == true
                            ? r.lectureCode!
                            : 'Not specified';
                        return ListTile(
                          title: Text(
                            r.text.length > 50 ? '${r.text.substring(0, 50)}...' : r.text,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Lecture: $displayLecture'),
                              Text('Date: ${r.timestamp}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.green),
                                tooltip: 'Share Record',
                                onPressed: () => _shareRecord(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit',
                                onPressed: () => _editResult(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () => _deleteResult(r.id!),
                              ),
                            ],
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Record Details'),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (r.lectureCode?.isNotEmpty == true)
                                      Text(
                                        'Lecture: ${r.lectureCode!}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    const SizedBox(height: 8),
                                    Text('Date: ${r.timestamp}'),
                                    const SizedBox(height: 8),
                                    Text(r.text),
                                    const SizedBox(height: 12),
                                    if (r.imagePath.isNotEmpty)
                                      Image.file(
                                        File(r.imagePath),
                                        height: 200,
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, st) =>
                                            const Text("Image couldn't be loaded."),
                                      )
                                    else
                                      const Text("No image available."),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
