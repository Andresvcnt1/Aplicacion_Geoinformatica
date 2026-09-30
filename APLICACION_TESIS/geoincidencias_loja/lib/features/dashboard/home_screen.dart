import 'package:flutter/material.dart';
import '../reporte/reporte_screen.dart';
import '../mapa/mapa_incidencias_screen.dart';
import '../perfil/perfil_screen.dart';
import '../publicaciones/publicaciones_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Sube cada vez que se entra a la pestaña Perfil. Así el Perfil se vuelve a
  // cargar (los números de las tarjetas quedan al día tras enviar un reporte)
  // y se ve su animación de entrada.
  int _visitasPerfil = 0;

  List<Widget> get _screens => [
    const MapaIncidenciasScreen(),
    const PublicacionesScreen(),
    const ReporteScreen(),
    PerfilScreen(key: ValueKey(_visitasPerfil)),
  ];

  void _onItemTapped(int index) {
    setState(() {
      if (index == 3 && _selectedIndex != 3) _visitasPerfil++;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Publicaciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Reportar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
