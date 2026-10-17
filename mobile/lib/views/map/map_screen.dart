import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/config.dart';
import '../../models/graffiti.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../ar/ar_view.dart';
import '../claim/claim_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  LatLng? _currentPosition;
  List<Graffiti> _nearbyGraffitis = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUsingSimulatedGps = false;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // 1. Inicializa autenticação com login guest transparente
    await AuthService.ensureAuthenticated();
    // 2. Inicia rastreamento GPS
    await _initLocationTracking();
  }

  Future<void> _initLocationTracking({bool forceMock = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (forceMock) {
      _applyMockPosition();
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // No PC local ou emulador sem GPS configurado: ativa automaticamente o modo de teste
        _applyMockPosition();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _applyMockPosition();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _applyMockPosition();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = latLng;
        _isUsingSimulatedGps = false;
        _isLoading = false;
      });

      _fetchNearby(position.latitude, position.longitude);

      // Acompanhamento contínuo se o GPS nativo estiver ativo
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted || _isUsingSimulatedGps) return;
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
        _fetchNearby(pos.latitude, pos.longitude);
      });
    } catch (e) {
      // Fallback amigável para teste no PC: usa coordenadas de teste
      _applyMockPosition();
    }
  }

  void _applyMockPosition() {
    const mockPos = LatLng(AppConfig.defaultTestLatitude, AppConfig.defaultTestLongitude);
    setState(() {
      _currentPosition = mockPos;
      _isUsingSimulatedGps = true;
      _isLoading = false;
      _errorMessage = null;
    });
    _fetchNearby(mockPos.latitude, mockPos.longitude);
  }

  Future<void> _fetchNearby(double lat, double lon) async {
    try {
      final list = await _apiService.getNearbyGraffiti(lat: lat, lon: lon, radius: 100);
      if (mounted) {
        setState(() {
          _nearbyGraffitis = list;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar grafites: $e');
    }
  }

  /// Permite "andar" pelo mapa clicando nele quando em modo de teste simulado no PC
  void _onMapTapped(TapPosition tapPosition, LatLng latLng) {
    if (_isUsingSimulatedGps) {
      setState(() {
        _currentPosition = latLng;
      });
      _fetchNearby(latLng.latitude, latLng.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Iniciando mapa local...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.brush, color: Colors.purpleAccent),
            const SizedBox(width: 8),
            Text(
              AuthService.username != null ? 'AR Graffiti (${AuthService.username})' : 'AR Graffiti',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar grafites próximos',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_currentPosition != null) {
                _fetchNearby(_currentPosition!.latitude, _currentPosition!.longitude);
              }
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition!,
              initialZoom: 18.0,
              onTap: _onMapTapped,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.argraffiti.app',
              ),
              MarkerLayer(
                markers: [
                  // Marcador do Jogador
                  Marker(
                    point: _currentPosition!,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Icon(Icons.navigation, color: Colors.white, size: 22),
                    ),
                  ),
                  // Marcadores de Grafites Próximos
                  ..._nearbyGraffitis.map((g) {
                    final isProtected = g.isProtected;
                    return Marker(
                      point: LatLng(g.latitude, g.longitude),
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () => _showGraffitiDetails(g),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isProtected ? Colors.amber[700] : Colors.purpleAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2))
                            ],
                          ),
                          child: Icon(
                            isProtected ? Icons.shield : Icons.auto_awesome,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Banner informativo quando testando com GPS Simulado no PC
          if (_isUsingSimulatedGps)
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, color: Colors.purpleAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modo Teste Local: Toque em qualquer lugar do mapa para mover o jogador.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Botões de Ação na parte inferior
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Abrir Câmera AR
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('Visão AR', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ARViewScreen(
                          nearbyGraffitis: _nearbyGraffitis,
                          currentPosition: _currentPosition!,
                        ),
                      ),
                    );
                  },
                ),
                // Reivindicar / Grafitar
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Grafitar Aqui', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClaimScreen(currentPosition: _currentPosition!),
                      ),
                    ).then((_) {
                      if (_currentPosition != null) {
                        _fetchNearby(_currentPosition!.latitude, _currentPosition!.longitude);
                      }
                    });
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final remaining = local.difference(DateTime.now());
    if (remaining.inDays > 1) return 'em ${remaining.inDays} dias';
    if (remaining.inDays == 1) return 'amanhã';
    if (remaining.inHours > 0) return 'em ${remaining.inHours}h';
    if (remaining.inMinutes > 0) return 'em ${remaining.inMinutes} min';
    return 'expirando agora';
  }

  void _showGraffitiDetails(Graffiti g) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  g.isProtected ? Icons.shield : Icons.sports_kabaddi,
                  color: g.isProtected ? Colors.amber[800] : Colors.green[700],
                ),
                const SizedBox(width: 8),
                Text(
                  g.isProtected ? 'Grafite Protegido (24h)' : 'Grafite Conquistável!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: g.isProtected ? Colors.amber[800] : Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Superfície: ${g.surfaceType.toDisplayName()}'),
            Text('Distância aproximada: ${g.distanceMeters ?? "?"} m'),
            Text('Expira: ${_formatDate(g.expiresAt)}'),
            const SizedBox(height: 12),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: g.mediaUrl,
                  height: 150,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                icon: const Icon(Icons.flag),
                label: const Text('Denunciar Imagem Imprópria'),
                onPressed: () async {
                  try {
                    await _apiService.reportGraffiti(graffitiId: g.id);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Denúncia registrada com sucesso.')),
                    );
                    if (_currentPosition != null) {
                      _fetchNearby(_currentPosition!.latitude, _currentPosition!.longitude);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
