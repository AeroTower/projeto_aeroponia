import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // Garante a inicialização das rotinas nativas antes de carregar o .env
  WidgetsFlutterBinding.ensureInitialized();
  
try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Aviso: Não foi possível carregar o ficheiro .env: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HidroApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}