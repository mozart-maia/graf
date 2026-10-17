import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Altere o IP abaixo se for rodar o app Flutter em um aparelho celular físico
  /// conectado na mesma rede Wi-Fi do seu computador (Ex: 'http://192.168.1.50:8000').
  /// Deixando vazio (''), o sistema detecta automaticamente se é emulador ou desktop.
  static const String manualHostOverride = 'http://192.168.15.112:8000';

  static String get apiBaseUrl => '$serverBaseUrl/api/v1';

  static String get serverBaseUrl {
    if (manualHostOverride.isNotEmpty) {
      return manualHostOverride;
    }
    if (!kIsWeb && Platform.isAndroid) {
      // 10.0.2.2 é a rota padrão do emulador Android para o localhost do computador host
      return 'http://10.0.2.2:8000';
    }
    // Windows, macOS, Linux, iOS Simulator e fallback
    return 'http://localhost:8000';
  }

  /// Coordenada simulada de GPS para testes rápidos no PC (Avenida Paulista, SP)
  /// Caso o dispositivo/emulador local não tenha sinal de GPS real ou esteja no PC Desktop.
  static const double defaultTestLatitude = -23.561684;
  static const double defaultTestLongitude = -46.655981;
}
