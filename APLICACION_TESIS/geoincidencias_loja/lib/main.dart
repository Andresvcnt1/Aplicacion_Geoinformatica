import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_service.dart';
import 'features/historial/incidencia_detalle_screen.dart';
import 'features/splash/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

bool _firebaseDisponible = false;
bool _notificacionesConfiguradas = false;
bool _rutaInicialReemplazada = false;
RemoteMessage? _mensajeInicialPendiente;

class _NotificacionNavigatorObserver extends NavigatorObserver {
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _rutaInicialReemplazada = true;
    _procesarMensajeInicialSiListo();
  }
}

void _procesarMensajeInicialSiListo() {
  final message = _mensajeInicialPendiente;
  if (message == null || !_rutaInicialReemplazada) return;

  _mensajeInicialPendiente = null;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_abrirIncidenciaDesdeNotificacion(message));
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    _firebaseDisponible = true;
  } catch (error) {
    debugPrint('No se pudo inicializar Firebase: $error');
  }

  runApp(const MyApp());
  unawaited(configurarNotificaciones());
}

Future<void> configurarNotificaciones() async {
  if (!_firebaseDisponible || _notificacionesConfiguradas) return;
  _notificacionesConfiguradas = true;

  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    FirebaseMessaging.onMessage.listen((message) {
      final body = message.notification?.body;
      if (body == null || body.isEmpty) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(body)),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_abrirIncidenciaDesdeNotificacion(message));
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _mensajeInicialPendiente = initialMessage;
      _procesarMensajeInicialSiListo();
    }

    messaging.onRegistered.listen(
      (_) async {
        try {
          // El backend requiere el token de registro FCM, no el Firebase Installation ID.
          // ignore: deprecated_member_use
          final token = await messaging.getToken();
          if (token == null) return;
          final preferences = await SharedPreferences.getInstance();
          if (preferences.getString('access_token') != null) {
            unawaited(ApiService().registrarTokenPush(token));
          }
        } catch (error) {
          debugPrint('No se pudo registrar el token FCM actualizado: $error');
        }
      },
      onError: (Object error) {
        debugPrint('Error al registrar el token FCM: $error');
      },
    );
  } catch (error) {
    debugPrint('No se pudieron configurar las notificaciones: $error');
  }
}

Future<void> _abrirIncidenciaDesdeNotificacion(RemoteMessage message) async {
  final incidenciaId = int.tryParse(message.data['incidencia_id'] ?? '');
  if (incidenciaId == null) {
    debugPrint('La notificación no contiene un incidencia_id válido.');
    return;
  }

  try {
    final incidencia = await ApiService().obtenerReportePorId(incidenciaId);
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint(
        'No se pudo navegar a la incidencia: Navigator no disponible.',
      );
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => IncidenciaDetalleScreen(incidencia: incidencia),
      ),
    );
  } catch (error) {
    debugPrint('No se pudo abrir la incidencia $incidenciaId: $error');
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el reporte notificado.')),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorObservers: [_NotificacionNavigatorObserver()],
      title: 'GeoIncidencias Loja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
      ),
      home: const SplashScreen(),
    );
  }
}
