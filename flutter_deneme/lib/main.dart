import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';             // ← dotenv
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'theme/theme_provider.dart';
import 'services/db_helper.dart';
import 'services/notification_service.dart';

import 'pages/home_page.dart';
import 'pages/camera_page.dart';
import 'pages/result_page.dart';
import 'pages/records_page.dart';
import 'pages/settings_page.dart';

/// Single, global instance of the notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Load .env (so you can read BACKEND_URL in your OCR client)
  await dotenv.load(fileName: ".env");

  // 2️⃣ Initialize your local-notifications helper
  await NotificationService.init();

  // 3️⃣ Initialize your SQLite (or whichever) database
  await DBHelper.database;

  // 4️⃣ Configure & initialize the system notifications
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // 5️⃣ Run the app, wiring up your ThemeProvider
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'PaperTrails OCR Scanner',
      debugShowCheckedModeBanner: false,

      // Localization
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('tr'),
      ],

      // Theme
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProv.themeMode,

      // Routes
      initialRoute: '/',
      routes: {
        '/':        (_) => const HomePage(),
        '/camera':  (_) => const CameraPage(),
        '/result':  (_) => const ResultPage(),
        '/records': (_) => const RecordsPage(),
        '/settings':(_) => const SettingsPage(),
      },
    );
  }
}
