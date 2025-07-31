import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

/// Mirror these enums from your SettingsPage (or import them)
enum ExportFormat { pdf, text, both }
enum SaveLocation { temp, documents }

class PdfService {
  /// Builds PDF and/or TXT exports according to user preferences.
  static Future<File> buildDocument(List<String> pages) async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Export format
    final fmt     = ExportFormat.values[prefs.getInt('exportFormat') ?? 0];
    final pattern = prefs.getString('fileNamePattern') ?? 'OCR_{date}_{time}';

    // 2) Save location
    final loc     = SaveLocation.values[prefs.getInt('saveLocation') ?? 0];
    final dir = (loc == SaveLocation.documents)
        ? await getApplicationDocumentsDirectory()
        : await getTemporaryDirectory();

    // 3) Generate base filename
    final now  = DateTime.now();
    final date = DateFormat('yyyyMMdd').format(now);
    final time = DateFormat('HHmmss').format(now);
    final baseName = pattern
        .replaceAll('{date}', date)
        .replaceAll('{time}', time);

    File pdfFile = File(''); // placeholder

    // 4) Create PDF if needed
    if (fmt == ExportFormat.pdf || fmt == ExportFormat.both) {
      final doc = pw.Document();
      for (var i = 0; i < pages.length; i++) {
        doc.addPage(
          pw.Page(
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Removed `const` here
                pw.Text(
                  'Page ${i + 1}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(pages[i]),
              ],
            ),
          ),
        );
      }
      final bytes = await doc.save();
      pdfFile = File('${dir.path}/$baseName.pdf')
        ..writeAsBytesSync(bytes);
    }

    // 5) Create TXT if needed
    if (fmt == ExportFormat.text || fmt == ExportFormat.both) {
      final textFile = File('${dir.path}/$baseName.txt');
      await textFile.writeAsString(pages.join('\n\n'));
    }

    // 6) Return the PDF file (or placeholder if only TXT)
    return pdfFile;
  }
}
