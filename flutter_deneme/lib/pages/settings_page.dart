import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/theme_provider.dart';
import '../services/db_helper.dart';

/// Supported crop aspect‑ratio options
enum CropAspectRatio { free, square, ratio4_3, ratio16_9 }

/// Supported export formats
enum ExportFormat { pdf, text, both }

/// Where to save exported files
enum SaveLocation { temp, documents }

/// Available OCR languages
const Map<String, String> _allLanguages = {
  'en': 'English',
  'tr': 'Turkish',
  'es': 'Spanish',
  'fr': 'French',
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 1️ OCR & Pre‑Processing & Crop
  List<String>       _ocrLanguages     = [];
  bool               _autoContrast     = false;
  bool               _deSkew           = false;
  bool               _binarize         = false;
  CropAspectRatio    _cropAspectRatio  = CropAspectRatio.free;

  // 2️ File & Export
  ExportFormat       _exportFormat     = ExportFormat.pdf;
  String             _fileNamePattern  = 'OCR_{date}_{time}';
  SaveLocation       _saveLocation     = SaveLocation.temp;

  // 3️ Other settings
  bool               _autoSave         = true;
  String             _appVersion       = 'Loading...';
  double             _textScaleFactor  = 1.0;
  
  // Notification settings
  bool?              _notificationsEnabled = true;
  bool?              _notifyOcrComplete    = true;
  bool?              _notifyExport         = true;
  bool?              _notificationVibrate  = true;
  bool?              _notificationSound    = true;

  @override
  void initState() {
    super.initState();
    _loadAllPrefs();
    _loadAppVersion();
  }
  Future<void> _loadAllPrefs() async {
    // Load all preferences in parallel
    final prefs = await SharedPreferences.getInstance();
    _textScaleFactor = prefs.getDouble('textScaleFactor') ?? 1.0;
    setState(() {
      // OCR languages
      _ocrLanguages     = prefs.getStringList('ocrLanguages') ?? ['en'];
      // Pre‑processing
      _autoContrast     = prefs.getBool('preprocess_contrast') ?? false;
      _deSkew           = prefs.getBool('preprocess_deskew')   ?? false;
      _binarize         = prefs.getBool('preprocess_binarize') ?? false;
      // Crop ratio
      final arIndex     = prefs.getInt('cropAspectRatio')      ?? 0;
      _cropAspectRatio  = CropAspectRatio.values[arIndex];
      // Auto‑save
      _autoSave         = prefs.getBool('autoSave')           ?? true;
      // Notifications
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notifyOcrComplete    = prefs.getBool('notify_ocr_complete')   ?? true;
      _notifyExport         = prefs.getBool('notify_export')         ?? true;
      _notificationVibrate  = prefs.getBool('notification_vibrate')  ?? true;
      _notificationSound    = prefs.getBool('notification_sound')    ?? true;
      final efIndex     = prefs.getInt('exportFormat')        ?? 0;
      _exportFormat     = ExportFormat.values[efIndex];
      _fileNamePattern  = prefs.getString('fileNamePattern')  ?? _fileNamePattern;
      final slIndex     = prefs.getInt('saveLocation')        ?? 0;
      _saveLocation     = SaveLocation.values[slIndex];
      // Auto‑save
      _autoSave         = prefs.getBool('autoSave')           ?? true;
    });
  }

  Future<void> _saveList(String key, List<String> list) =>
      SharedPreferences.getInstance().then((p) => p.setStringList(key, list));

  Future<void> _saveBool(String key, bool val) =>
      SharedPreferences.getInstance().then((p) => p.setBool(key, val));

  Future<void> _saveInt(String key, int val) =>
      SharedPreferences.getInstance().then((p) => p.setInt(key, val));

  Future<void> _saveString(String key, String val) =>
      SharedPreferences.getInstance().then((p) => p.setString(key, val));

  Future<void> _saveDouble(String key, double val) =>
    SharedPreferences.getInstance().then((p) => p.setDouble(key, val));

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${info.appName} v${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      setState(() => _appVersion = 'Failed to get version');
    }
  }

  void _confirmClearRecords() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Delete all saved OCR records?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await DBHelper.clearAll();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('All records cleared')));
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  void _confirmResetApp() => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reset App'),
          content: const Text('This will delete ALL data and reset settings. Proceed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await DBHelper.clearAll();
                  _fileNamePattern  = 'OCR_{date}_{time}';
                  _saveLocation     = SaveLocation.temp;
                  _autoSave         = true;
                  _notificationsEnabled = true;
                  _notifyOcrComplete    = true;
                  _notifyExport         = true;
                  _notificationVibrate  = true;
                  _notificationSound    = true;
                await Provider.of<ThemeProvider>(context, listen: false)
                    .setAppThemeMode(AppThemeMode.system);
                // Reset local state
                setState(() {
                  _ocrLanguages     = ['en'];
                  _autoContrast     = false;
                  _deSkew           = false;
                  _binarize         = false;
                  _cropAspectRatio  = CropAspectRatio.free;
                  _exportFormat     = ExportFormat.pdf;
                  _fileNamePattern  = 'OCR_{date}_{time}';
                  _saveLocation     = SaveLocation.temp;
                  _autoSave         = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App reset complete')),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── App Theme ────────────────────────────────
          Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Text Size',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      Slider(
        min: 0.8,
        max: 2.0,
        divisions: 12,
        label: '${(_textScaleFactor * 100).round()}%',
        value: _textScaleFactor,
        onChanged: (v) {
          setState(() => _textScaleFactor = v);
          _saveDouble('textScaleFactor', v);
        },
      ),
    ],
  ),
),
          RadioListTile<AppThemeMode>(
            title: const Text('System Default'),
            value: AppThemeMode.system,
            groupValue: themeProv.appThemeMode,
            onChanged: (m) {
              if (m == null) return;
              themeProv.setAppThemeMode(m);
            },
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Light'),
            value: AppThemeMode.light,
            groupValue: themeProv.appThemeMode,
            onChanged: (m) {
              if (m == null) return;
              themeProv.setAppThemeMode(m);
            },
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Dark'),
            value: AppThemeMode.dark,
            groupValue: themeProv.appThemeMode,
            onChanged: (m) {
              if (m == null) return;
              themeProv.setAppThemeMode(m);
            },
          ),

          const Divider(),

          // ── 1. OCR Languages ─────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('OCR Languages',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ..._allLanguages.entries.map((e) {
            final code = e.key, name = e.value;
            return CheckboxListTile(
              title: Text(name),
              value: _ocrLanguages.contains(code),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _ocrLanguages.add(code);
                  } else {
                    _ocrLanguages.remove(code);
                  }
                });
                _saveList('ocrLanguages', _ocrLanguages);
              },
            );
          }),

          const Divider(),

          // ── 2. Pre‑Processing ────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Pre‑Processing',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Auto‑Contrast'),
            subtitle: const Text('Boost image contrast before OCR'),
            value: _autoContrast,
            onChanged: (v) {
              setState(() => _autoContrast = v);
              _saveBool('preprocess_contrast', v);
            },
          ),
          SwitchListTile(
            title: const Text('De‑Skew'),
            subtitle: const Text('Automatically straighten skewed images'),
            value: _deSkew,
            onChanged: (v) {
              setState(() => _deSkew = v);
              _saveBool('preprocess_deskew', v);
            },
          ),
          SwitchListTile(
            title: const Text('Binarization'),
            subtitle: const Text('Convert to black & white before OCR'),
            value: _binarize,
            onChanged: (v) {
              setState(() => _binarize = v);
              _saveBool('preprocess_binarize', v);
            },
          ),

          const Divider(),

          // ── 3. Crop Aspect Ratio ─────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Crop Aspect Ratio',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          RadioListTile<CropAspectRatio>(
            title: const Text('Free (any)'),
            value: CropAspectRatio.free,
            groupValue: _cropAspectRatio,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cropAspectRatio = v);
              _saveInt('cropAspectRatio', v.index);
            },
          ),
          RadioListTile<CropAspectRatio>(
            title: const Text('Square (1:1)'),
            value: CropAspectRatio.square,
            groupValue: _cropAspectRatio,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cropAspectRatio = v);
              _saveInt('cropAspectRatio', v.index);
            },
          ),
          RadioListTile<CropAspectRatio>(
            title: const Text('4:3'),
            value: CropAspectRatio.ratio4_3,
            groupValue: _cropAspectRatio,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cropAspectRatio = v);
              _saveInt('cropAspectRatio', v.index);
            },
          ),
          RadioListTile<CropAspectRatio>(
            title: const Text('16:9'),
            value: CropAspectRatio.ratio16_9,
            groupValue: _cropAspectRatio,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cropAspectRatio = v);
              _saveInt('cropAspectRatio', v.index);
            },
          ),

          const Divider(),

          // ── 4. Export Preferences ─────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Export Preferences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ExportFormat>(
            title: const Text('PDF only'),
            value: ExportFormat.pdf,
            groupValue: _exportFormat,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _exportFormat = v);
              _saveInt('exportFormat', v.index);
            },
          ),
          RadioListTile<ExportFormat>(
            title: const Text('Text only'),
            value: ExportFormat.text,
            groupValue: _exportFormat,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _exportFormat = v);
              _saveInt('exportFormat', v.index);
            },
          ),
          RadioListTile<ExportFormat>(
            title: const Text('Both PDF & Text'),
            value: ExportFormat.both,
            groupValue: _exportFormat,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _exportFormat = v);
              _saveInt('exportFormat', v.index);
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextFormField(
              initialValue: _fileNamePattern,
              decoration: const InputDecoration(
                labelText: 'File‑Name Pattern',
                helperText: 'Use {date} and {time} placeholders',
              ),
              onChanged: (v) {
                setState(() => _fileNamePattern = v);
                _saveString('fileNamePattern', v);
              },
            ),
          ),

          RadioListTile<SaveLocation>(
            title: const Text('Save to Temporary Directory'),
            value: SaveLocation.temp,
            groupValue: _saveLocation,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _saveLocation = v);
              _saveInt('saveLocation', v.index);
            },
          ),
          RadioListTile<SaveLocation>(
            title: const Text('Save to Documents Directory'),
            value: SaveLocation.documents,
            groupValue: _saveLocation,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _saveLocation = v);
              _saveInt('saveLocation', v.index);
            },
          ),

          const Divider(),

          // ── 5. Other Settings ────────────────────────────
          SwitchListTile(
            title: const Text('Auto‑Save OCR Results'),
            subtitle: const Text('Automatically save each scanned result'),
            value: _autoSave,
            onChanged: (v) {
              setState(() => _autoSave = v);
              _saveBool('autoSave', v);
            },
          ),
          ListTile(
            title: const Text('Clear All Records'),
            subtitle: const Text('Delete all saved OCR results'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: _confirmClearRecords,
          ),
          ListTile(
            title: const Text('Reset App', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Delete all data and reset settings'),
            trailing: const Icon(Icons.restart_alt, color: Colors.red),
            onTap: _confirmResetApp,
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About This App'),
            subtitle: Text(_appVersion),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: _appVersion,
              applicationVersion: _appVersion,
              applicationLegalese: '© 2025 Ahmet Akın',
              children: const [
                SizedBox(height: 10),
                Text('This app performs OCR on images and saves the results locally.'),
                SizedBox(height: 5),
                Text('Contact: ahmet.akin045@gmail.com'),  
              ],
            ),
          ),
          const Divider(),
          // ── 6. Notifications ────────────────────────────
            const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Allow app to send notifications'),
            value: _notificationsEnabled ?? true,
            onChanged: (v) {
              setState(() => _notificationsEnabled = v);
              _saveBool('notifications_enabled', v);
            },
            ),
            if (_notificationsEnabled ?? true) ...[
            SwitchListTile(
              title: const Text('OCR Completion Alerts'),
              subtitle: const Text('Notify when OCR processing completes'),
              value: _notifyOcrComplete ?? true,
              onChanged: (v) {
              setState(() => _notifyOcrComplete = v);
              _saveBool('notify_ocr_complete', v);
              },
              dense: true,
              contentPadding: const EdgeInsets.only(left: 28, right: 16),
            ),
            SwitchListTile(
              title: const Text('Export Notifications'),
              subtitle: const Text('Notify when files are exported'),
              value: _notifyExport ?? true,
              onChanged: (v) {
              setState(() => _notifyExport = v);
              _saveBool('notify_export', v);
              },
              dense: true,
              contentPadding: const EdgeInsets.only(left: 28, right: 16),
            ),
            SwitchListTile(
              title: const Text('Vibration'),
              subtitle: const Text('Vibrate with notifications'),
              value: _notificationVibrate ?? true,
              onChanged: (v) {
              setState(() => _notificationVibrate = v);
              _saveBool('notification_vibrate', v);
              },
              dense: true,
              contentPadding: const EdgeInsets.only(left: 28, right: 16),
            ),
            SwitchListTile(
              title: const Text('Sound'),
              subtitle: const Text('Play sound with notifications'),
              value: _notificationSound ?? true,
              onChanged: (v) {
              setState(() => _notificationSound = v);
              _saveBool('notification_sound', v);
              },
              dense: true,
              contentPadding: const EdgeInsets.only(left: 28, right: 16),
            ),
            ],
        ],
      ),
    );
  }
}
