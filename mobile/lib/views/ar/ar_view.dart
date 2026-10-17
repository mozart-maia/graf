import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:arcore_flutter_plus/arcore_flutter_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../models/graffiti.dart';

/// Tela de visualização de Realidade Aumentada (ARCore).
/// Detecta planos reais (paredes e superfícies verticais/horizontais) usando a câmera
/// e ancora o grafite na superfície física com perspectiva e escala realistas.
/// Também oferece modo 2D de fallback para testes em emuladores ou dispositivos sem ARCore.
class ARViewScreen extends StatefulWidget {
  final List<Graffiti> nearbyGraffitis;
  final LatLng currentPosition;

  const ARViewScreen({
    super.key,
    required this.nearbyGraffitis,
    required this.currentPosition,
  });

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  ArCoreController? _arCoreController;
  int _selectedIndex = 0;
  bool _useARCore = true;
  bool _isDownloadingImage = false;
  bool _hasPlacedNode = false;
  String _statusMessage = 'Aponte a câmera para uma parede e mova suavemente...';

  // Cache das imagens baixadas para textura rápida no ARCore
  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _preloadCurrentGraffiti();
  }

  @override
  void dispose() {
    _arCoreController?.dispose();
    super.dispose();
  }

  /// Baixa os bytes da imagem do grafite para alimentar a textura do ARCore
  Future<Uint8List?> _getGraffitiBytes(String url) async {
    if (_imageCache.containsKey(url)) {
      return _imageCache[url];
    }
    try {
      setState(() => _isDownloadingImage = true);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        _imageCache[url] = response.bodyBytes;
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Erro ao baixar textura para AR: $e');
    } finally {
      if (mounted) {
        setState(() => _isDownloadingImage = false);
      }
    }
    return null;
  }

  void _preloadCurrentGraffiti() {
    if (widget.nearbyGraffitis.isNotEmpty) {
      _getGraffitiBytes(widget.nearbyGraffitis[_selectedIndex].mediaUrl);
    }
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    _arCoreController = controller;
    _arCoreController?.onPlaneTap = _handlePlaneTap;

    setState(() {
      _statusMessage = 'Plano sendo rastreado. Toque na parede quando os pontos surgirem!';
    });
  }

  /// Disparado quando o usuário toca em uma superfície detectada pelo ARCore
  Future<void> _handlePlaneTap(List<ArCoreHitTestResult> hits) async {
    if (hits.isEmpty) return;
    if (widget.nearbyGraffitis.isEmpty) return;

    final hit = hits.first;
    final currentGraffiti = widget.nearbyGraffitis[_selectedIndex];

    setState(() {
      _statusMessage = 'Fixando grafite na parede...';
    });

    final imageBytes = await _getGraffitiBytes(currentGraffiti.mediaUrl);

    // Se falhar o download da textura, usa cor de destaque
    final material = ArCoreMaterial(
      color: Colors.white,
      textureBytes: imageBytes,
      roughness: 0.8,
    );

    // Cria um painel fino tipo pôster/grafite (0.8m x 0.8m x 0.01m de espessura)
    final shape = ArCoreCube(
      materials: [material],
      size: vector.Vector3(0.8, 0.8, 0.01),
    );

    final node = ArCoreNode(
      shape: shape,
      position: hit.pose.translation,
      rotation: hit.pose.rotation,
    );

    // Âncora o nó no plano físico detectado pelo ARCore
    _arCoreController?.addArCoreNodeWithAnchor(node);

    if (mounted) {
      setState(() {
        _hasPlacedNode = true;
        _statusMessage = '🎉 Arte fixada na parede! Ande ao redor para ver a perspectiva.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Grafite "${currentGraffiti.surfaceType.toDisplayName()}" fixado com sucesso!'),
          backgroundColor: Colors.purple,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGraffitis = widget.nearbyGraffitis.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_useARCore ? 'ARCore Câmera Real' : 'Visor Espacial 2D'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          // Botão para alternar entre Câmera ARCore e Simulação 2D
          IconButton(
            tooltip: _useARCore ? 'Mudar para Visor 2D' : 'Mudar para Câmera ARCore',
            icon: Icon(_useARCore ? Icons.view_in_ar : Icons.camera_alt),
            onPressed: () {
              setState(() {
                _useARCore = !_useARCore;
              });
            },
          ),
        ],
      ),
      body: !hasGraffitis
          ? _buildEmptyState()
          : Stack(
              children: [
                // Camada principal: ARCore real ou Visor 2D
                Positioned.fill(
                  child: _useARCore ? _buildARCoreView() : _build2DViewer(),
                ),

                // Barra superior de status e instruções
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildInstructionCard(),
                ),

                // Carrossel inferior com as artes no raio de GPS
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomCarousel(),
                ),
              ],
            ),
    );
  }

  /// Visor ARCore com renderização da câmera e detecção de planos
  Widget _buildARCoreView() {
    return ArCoreView(
      onArCoreViewCreated: _onArCoreViewCreated,
      enablePlaneRenderer: true,
      enableTapRecognizer: true,
    );
  }

  /// Fallback: Visor espacial estilizado em 2D com CustomPainter
  Widget _build2DViewer() {
    final graffiti = widget.nearbyGraffitis[_selectedIndex];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (graffiti.isProtected ? Colors.amber : Colors.purpleAccent).withAlpha(100),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: graffiti.mediaUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.white38),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    final graffiti = widget.nearbyGraffitis[_selectedIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                graffiti.isProtected ? Icons.shield : Icons.auto_awesome,
                color: graffiti.isProtected ? Colors.amber : Colors.purpleAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${graffiti.surfaceType.toDisplayName()} · ${graffiti.distanceMeters?.toStringAsFixed(1) ?? "0"}m de distância',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isDownloadingImage)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _useARCore
                ? _statusMessage
                : 'Modo Simulado 2D ativado (toque no ícone de câmera para voltar ao ARCore).',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCarousel() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Grafites Próximos (${widget.nearbyGraffitis.length}) - Escolha qual projetar:',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.nearbyGraffitis.length,
              itemBuilder: (ctx, index) {
                final g = widget.nearbyGraffitis[index];
                final isSelected = index == _selectedIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    _preloadCurrentGraffiti();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    width: 82,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.deepPurple.withAlpha(90) : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.purpleAccent : Colors.white24,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: g.mediaUrl,
                            height: 48,
                            width: 66,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                            ),
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 20),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${g.distanceMeters?.toStringAsFixed(0) ?? "?"}m',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 72, color: Colors.white38),
            SizedBox(height: 20),
            Text(
              'Nenhum grafite encontrado neste raio geográfico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Aproxime-se de um local com grafites no mapa ou seja o primeiro a grafitar aqui!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
