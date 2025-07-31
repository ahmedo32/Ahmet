import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OCRClient {
  final _endpoint = dotenv.env['BACKEND_URL']!;

  Future<String> extractText(Uint8List imageBytes) async {
    final b64 = base64Encode(imageBytes);
    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': b64}),
    );
    final data = jsonDecode(resp.body);
    return data['text'] as String;
  }
}