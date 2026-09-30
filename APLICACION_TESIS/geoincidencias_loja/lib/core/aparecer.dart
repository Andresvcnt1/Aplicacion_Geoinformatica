import 'package:flutter/material.dart';

/// Hace que un elemento aparezca con un fundido y un deslizamiento suave hacia
/// arriba. Sirve para toda la app, así el movimiento es coherente.
///
/// Para escalonar varios elementos, dales `orden` 0, 1, 2... y cada uno entrará
/// un instante después del anterior.
///
/// Respeta el ajuste de accesibilidad "quitar animaciones" del teléfono.
class Aparecer extends StatefulWidget {
  final Widget child;
  final int orden;
  final Duration duracion;
  final double desplazamiento;

  const Aparecer({
    super.key,
    required this.child,
    this.orden = 0,
    this.duracion = const Duration(milliseconds: 450),
    this.desplazamiento = 18,
  });

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animacion;

  @override
  void initState() {
    super.initState();
    final retardoMs = 60 * widget.orden;
    final totalMs = retardoMs + widget.duracion.inMilliseconds;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _animacion = CurvedAnimation(
      parent: _controller,
      curve: Interval(retardoMs / totalMs, 1.0, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    return AnimatedBuilder(
      animation: _animacion,
      child: widget.child,
      builder: (context, child) {
        final t = _animacion.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.desplazamiento),
            child: child,
          ),
        );
      },
    );
  }
}
