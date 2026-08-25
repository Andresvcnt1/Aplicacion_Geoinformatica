import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_service.dart';
import '../auth/login_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _perfil;
  bool _cargando = true;
  bool _subiendoFoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await _apiService.obtenerPerfil();
      if (!mounted) return;
      setState(() {
        _perfil = data;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el perfil';
        _cargando = false;
      });
    }
  }

  Future<void> _cambiarFotoPerfil() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (imagen == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final data = await _apiService.actualizarFotoPerfil(File(imagen.path));
      if (!mounted) return;
      setState(() {
        _perfil = data;
        _subiendoFoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Foto de perfil actualizada'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendoFoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudo actualizar la foto: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _metodoBiometricoLabel(String? metodo) {
    switch (metodo) {
      case 'facial':
        return 'Reconocimiento facial';
      case 'huella':
        return 'Huella digital';
      default:
        return 'No configurado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 50,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _cargarPerfil,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargarPerfil,
              color: Colors.teal,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // --- Cabecera tipo IG/Facebook ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 16,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00796B), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.teal.shade50,
                                backgroundImage:
                                    _perfil?['foto_perfil_url'] != null
                                    ? NetworkImage(_perfil!['foto_perfil_url'])
                                    : null,
                                child: _subiendoFoto
                                    ? const CircularProgressIndicator(
                                        color: Colors.teal,
                                      )
                                    : (_perfil?['foto_perfil_url'] == null
                                          ? const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Colors.teal,
                                            )
                                          : null),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _subiendoFoto
                                    ? null
                                    : _cambiarFotoPerfil,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.teal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _perfil?['username'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cédula: ${_perfil?['cedula'] ?? '-'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- Estadística: total de reportes ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${_perfil?['total_reportes'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Incidencias reportadas',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- Datos de la cuenta ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.email_outlined,
                              color: Colors.teal,
                            ),
                            title: const Text('Correo electrónico'),
                            subtitle: Text(_perfil?['email'] ?? '-'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.fingerprint,
                              color: Colors.teal,
                            ),
                            title: const Text('Verificación biométrica'),
                            subtitle: Text(
                              _metodoBiometricoLabel(
                                _perfil?['metodo_verificacion'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cerrarSesion,
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        label: const Text(
                          'Cerrar sesión',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
