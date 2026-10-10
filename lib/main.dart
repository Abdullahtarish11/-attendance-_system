import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/app_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print("Initializing Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print("Fetching organization...");
    await FirebaseService.instance.fetchOrganization();

    print("Fetching branches...");
    await FirebaseService.instance.fetchBranches();

    print("Initializing Notifications...");
    try {
      await NotificationService.instance.init();
    } catch (e) {
      print("Notification init failed: $e");
    }
  } catch (e) {
    print("Critical initialization error: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final org = provider.organization;
        final String orgName = org['name'] ?? 'نظام الحضور';
        final String colorStr = org['color'] ?? 'blue';
        
        // Basic mapping for colors (can be expanded)
        Color primarySwatch = Colors.blue;
        if (colorStr == 'red') primarySwatch = Colors.red;
        if (colorStr == 'green') primarySwatch = Colors.green;
        if (colorStr == 'orange') primarySwatch = Colors.orange;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: orgName,
          themeMode: provider.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: primarySwatch,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto', // Fallback to a standard modern font
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: primarySwatch,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar', 'SA'),
            Locale('en', 'US'),
          ],
          locale: const Locale('ar', 'SA'),
          home: const LoginPage(),
        );
      },
    );
  }
}
