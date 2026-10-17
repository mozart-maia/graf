import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../models/graffiti.dart';
import '../../services/api_service.dart';

class ClaimScreen extends StatefulWidget {
  final LatLng currentPosition;

  const ClaimScreen({super.key, required this.currentPosition});

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();

  File? _selectedFile;
  SurfaceType _selectedSurface = SurfaceType.verticalWall;
  bool _isUploading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
      });
    }
  }

  Future<void> _submitClaim() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma imagem ou GIF para pintar.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final result = await _apiService.claimSpot(
        lat: widget.currentPosition.latitude,
        lon: widget.currentPosition.longitude,
        surfaceType: _selectedSurface,
        imageFile: _selectedFile!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Arte gravada com sucesso! Local protegido por 24h.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reivindicar Espaço Físico')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.deepPurple),
                      SizedBox(width: 8),
                      Text(
                        'Regra Territorial (King of the Hill)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Você ocupará um raio de 10 metros. A arte fica protegida por 24 horas contra outras pinturas e expira em 7 dias.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Divider(height: 16),
                  Text(
                    'GPS: ${widget.currentPosition.latitude.toStringAsFixed(6)}, ${widget.currentPosition.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Superfície Alvo:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<SurfaceType>(
              initialValue: _selectedSurface,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: SurfaceType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toDisplayName()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSurface = val);
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Pré-visualização da Mídia:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(
              child: _selectedFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedFile!, height: 200, fit: BoxFit.cover),
                    )
                  : Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_search, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Nenhum arquivo 2D ou GIF escolhido', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeria / GIF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: (Platform.isAndroid || Platform.isIOS)
                        ? () => _pickImage(ImageSource.camera)
                        : null,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      (Platform.isAndroid || Platform.isIOS) ? 'Tirar Foto' : 'Câmera (N/D)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _isUploading
                ? const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Enviando arte para o servidor local...'),
                      ],
                    ),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    onPressed: _submitClaim,
                    icon: const Icon(Icons.brush),
                    label: const Text(
                      'Grafitar e Proteger Ponto',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
