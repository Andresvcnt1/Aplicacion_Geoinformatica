import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Área para tomar la foto de evidencia (RF003: obligatoria).
/// No contiene lógica: recibe la imagen y avisa con `onTap` cuando la persona
/// quiere tomar o cambiar la foto.
class FotoPicker extends StatelessWidget {
  final File? imagen;
  final bool cargando;
  final bool resaltarFalta;
  final VoidCallback onTap;

  const FotoPicker({
    super.key,
    required this.imagen,
    required this.cargando,
    required this.resaltarFalta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tieneFoto = imagen != null;
    final colorBorde = tieneFoto
        ? AppTheme.primario
        : (resaltarFalta ? Colors.red.shade600 : Colors.grey.shade300);

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: GestureDetector(
        onTap: cargando ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorBorde, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _contenido(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (cargando) {
      return const Center(
        key: ValueKey('cargando'),
        child: CircularProgressIndicator(color: AppTheme.primario),
      );
    }

    if (imagen != null) {
      return Stack(
        key: ValueKey(imagen!.path),
        fit: StackFit.expand,
        children: [
          Image.file(imagen!, fit: BoxFit.cover),
          const Positioned(
            top: 12,
            left: 12,
            child: _Pastilla(
              icono: Icons.check_circle,
              colorIcono: Colors.greenAccent,
              texto: 'Foto lista',
            ),
          ),
          const Positioned(
            bottom: 12,
            right: 12,
            child: _Pastilla(icono: Icons.camera_alt, texto: 'Cambiar'),
          ),
        ],
      );
    }

    return Center(
      key: const ValueKey('vacio'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primario.withValues(alpha: 0.10),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 30,
              color: AppTheme.primario,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Toca para tomar la foto',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.primarioOscuro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            resaltarFalta
                ? 'Falta la foto: es obligatoria'
                : 'Es obligatoria como evidencia',
            style: TextStyle(
              fontSize: 13,
              color: resaltarFalta ? Colors.red.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final String texto;

  const _Pastilla({
    required this.icono,
    required this.texto,
    this.colorIcono = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: colorIcono),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
