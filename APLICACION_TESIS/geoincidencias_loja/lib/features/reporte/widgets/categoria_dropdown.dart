import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';

/// Una categoría de incidencia. `valor` es lo que espera el backend
/// (AGUA, VIAL, LUZ, OTRO); `etiqueta` es solo el texto que ve la persona.
class CategoriaOpcion {
  final String valor;
  final String etiqueta;
  final IconData icono;

  const CategoriaOpcion(this.valor, this.etiqueta, this.icono);
}

class CategoriaSelector extends StatelessWidget {
  final List<CategoriaOpcion> opciones;
  final String seleccionada;
  final ValueChanged<String> onChanged;

  const CategoriaSelector({
    super.key,
    required this.opciones,
    required this.seleccionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];

    for (var i = 0; i < opciones.length; i += 2) {
      final par = opciones.skip(i).take(2).toList();

      filas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _tarjeta(par[0])),
              const SizedBox(width: 12),
              Expanded(
                child: par.length > 1 ? _tarjeta(par[1]) : const SizedBox(),
              ),
            ],
          ),
        ),
      );

      if (i + 2 < opciones.length) filas.add(const SizedBox(height: 12));
    }

    return Column(children: filas);
  }

  Widget _tarjeta(CategoriaOpcion opcion) {
    return _Opcion(
      opcion: opcion,
      activa: opcion.valor == seleccionada,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(opcion.valor);
      },
    );
  }
}

class _Opcion extends StatelessWidget {
  final CategoriaOpcion opcion;
  final bool activa;
  final VoidCallback onTap;

  const _Opcion({
    required this.opcion,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: activa
              ? AppTheme.primario.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activa ? AppTheme.primario : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activa
                    ? AppTheme.primario
                    : AppTheme.primario.withValues(alpha: 0.10),
              ),
              child: Icon(
                opcion.icono,
                size: 22,
                color: activa ? Colors.white : AppTheme.primario,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              opcion.etiqueta,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                color: activa ? AppTheme.primarioOscuro : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
