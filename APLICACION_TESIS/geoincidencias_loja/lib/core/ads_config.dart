import 'dart:io' show Platform;

/// Configuración de Google AdMob.
///
/// Hoy son IDs de PRUEBA que publica Google para desarrollo: muestran anuncios
/// de ejemplo y no generan ingresos. Para anuncios reales, crea tu cuenta de
/// AdMob, registra la app y reemplaza estos IDs (y el App ID del AndroidManifest).
class AdsConfig {
  AdsConfig._();

  /// AdMob solo existe en Android e iOS.
  static bool get soportado => Platform.isAndroid || Platform.isIOS;

  static String get bannerUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';
}
