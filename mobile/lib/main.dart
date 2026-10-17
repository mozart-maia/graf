import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'views/map/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa o serviço de autenticação com dados persistidos em cache
  await AuthService.init();
  runApp(const ARGraffitiApp());
}

class ARGraffitiApp extends StatelessWidget {
  const ARGraffitiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Graffiti',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const MapScreen(),
    );
  }
}
