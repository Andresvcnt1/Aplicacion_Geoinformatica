import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:geoincidencias_loja/core/ads_config.dart';
import 'package:geoincidencias_loja/core/theme.dart';

/// Espacio publicitario de Google AdMob dentro del feed (solo usuarios sin VIP).
class AdMobBanner extends StatefulWidget {
  final VoidCallback onQuitarAnuncios;
  const AdMobBanner({super.key, required this.onQuitarAnuncios});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _banner;
  bool _cargado = false;

  // Evita recargar el anuncio cada vez que se desplaza el feed
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!AdsConfig.soportado) return;
    _banner = BannerAd(
      adUnitId: AdsConfig.bannerUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _cargado = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob: no se pudo cargar el banner: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _banner = null;
              _cargado = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final banner = _banner;
    if (!_cargado || banner == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Publicidad · Google AdMob',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: banner.size.width.toDouble(),
              height: banner.size.height.toDouble(),
              child: AdWidget(ad: banner),
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  size: 18,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¿Prefieres no ver anuncios?',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onQuitarAnuncios,
                  child: const Text(
                    'Hazte VIP',
                    style: TextStyle(
                      color: AppTheme.primario,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
