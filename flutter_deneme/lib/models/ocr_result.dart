class OCRResult {
  final int? id;
  final String imagePath;
  final String text;
  final String timestamp;
  final String? lectureCode;
  final String? note;               // new
  final List<String>? tags;         // new

  OCRResult({
    this.id,
    required this.imagePath,
    required this.text,
    required this.timestamp,
    this.lectureCode,
    this.note,
    this.tags,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'imagePath': imagePath,
        'text': text,
        'timestamp': timestamp,
        'lectureCode': lectureCode,
        'note': note,
        'tags': tags?.join(','),
      };

  factory OCRResult.fromMap(Map<String, dynamic> m) => OCRResult(
        id: m['id'] as int?,
        imagePath: m['imagePath'],
        text: m['text'],
        timestamp: m['timestamp'],
        lectureCode: m['lectureCode'],
        note: m['note'],
        tags: m['tags'] != null && (m['tags'] as String).isNotEmpty
            ? (m['tags'] as String).split(',')
            : null,
      );
}
