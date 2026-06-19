import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum Lang { en, sk, de, es }

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  final GlobalKey _featuresKey = GlobalKey();
  Lang lang = Lang.en;

  @override
  void initState() {
    super.initState();
    try {
      final locale = WidgetsBinding.instance.platformDispatcher.locales.first;
      final code = locale.languageCode.toLowerCase();
      if (code.startsWith('sk')) {
        lang = Lang.sk;
      } else if (code.startsWith('de')) {
        lang = Lang.de;
      } else if (code.startsWith('es')) {
        lang = Lang.es;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          const _GlowBg(),
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 88),
                _TopNav(lang: lang, onLang: (v) => setState(() => lang = v)),
                _Hero(
                  lang: lang,
                  wide: wide,
                  onPrimaryTap: () => Navigator.of(context).pushNamed('/app'),
                  onSecondaryTap: _scrollToFeatures,
                ),
                _Stats(lang: lang, wide: wide),
                KeyedSubtree(
                  key: _featuresKey,
                  child: _Features(lang: lang, wide: wide),
                ),
                _Roadmap(lang: lang, wide: wide),
                _CTA(lang: lang, wide: wide),
                _Footer(lang: lang),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToFeatures() {
    final context = _featuresKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }
}

class _GlowBg extends StatelessWidget {
  const _GlowBg();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.15,
            colors: [Color(0x1AC9A84C), AppTheme.black],
          ),
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({required this.lang, required this.onLang});

  final Lang lang;
  final ValueChanged<Lang> onLang;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppTheme.black.withValues(alpha: .88),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: .08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'GoldTaxi',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Wrap(
            spacing: 6,
            children: [
              _langChip('EN', Lang.en),
              _langChip('SK', Lang.sk),
              _langChip('DE-CH', Lang.de),
              _langChip('ES', Lang.es),
            ],
          ),
        ],
      ),
    );
  }

  Widget _langChip(String label, Lang value) {
    final selected = lang == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onLang(value),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
      selectedColor: AppTheme.gold,
      backgroundColor: AppTheme.surface,
      side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.lang,
    required this.wide,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
  });
  final Lang lang;
  final bool wide;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: wide ? 72 : 20, vertical: wide ? 88 : 56),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          children: [
            _badge(_t(lang, 'hero_tag')),
            const SizedBox(height: 24),
            Text(
              'GoldTaxi',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: wide ? 88 : 52,
                height: .95,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t(lang, 'hero_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: wide ? 18 : 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _t(lang, 'hero_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: wide ? 16 : 14,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 34),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: onPrimaryTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Text(_t(lang, 'cta_book').toUpperCase()),
                ),
                OutlinedButton(
                  onPressed: onSecondaryTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: .14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Text(_t(lang, 'cta_demo').toUpperCase()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.lang, required this.wide});
  final Lang lang;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_t(lang, 'stat_1_title'), _t(lang, 'stat_1_desc')),
      (_t(lang, 'stat_2_title'), _t(lang, 'stat_2_desc')),
      (_t(lang, 'stat_3_title'), _t(lang, 'stat_3_desc')),
      (_t(lang, 'stat_4_title'), _t(lang, 'stat_4_desc')),
    ];
    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Wrap(
          spacing: 0,
          runSpacing: 0,
          children: items
              .map(
                (e) => SizedBox(
                  width: wide ? 300 : MediaQuery.sizeOf(context).width / 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Text(e.$1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 30,
                                fontWeight: FontWeight.w300)),
                        const SizedBox(height: 6),
                        Text(e.$2.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .5),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.lang, required this.wide});
  final Lang lang;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final features = [
      (_t(lang, 'feat1_title'), _t(lang, 'feat1_desc')),
      (_t(lang, 'feat2_title'), _t(lang, 'feat2_desc')),
      (_t(lang, 'feat3_title'), _t(lang, 'feat3_desc')),
      (_t(lang, 'feat4_title'), _t(lang, 'feat4_desc')),
      (_t(lang, 'feat5_title'), _t(lang, 'feat5_desc')),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 72 : 20, vertical: 84),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(lang, 'features_tag').toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Text(_t(lang, 'features_title'),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: wide ? 38 : 28,
                    fontWeight: FontWeight.w400,
                    height: 1.1)),
            const SizedBox(height: 18),
            Text(
              _t(lang, 'features_desc'),
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 34),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: features
                  .map(
                    (f) => Container(
                      width: wide ? 260 : double.infinity,
                      constraints: const BoxConstraints(minHeight: 150),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.radio_button_checked,
                              color: AppTheme.gold, size: 20),
                          const SizedBox(height: 14),
                          Text(f.$1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(
                            f.$2,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Roadmap extends StatelessWidget {
  const _Roadmap({required this.lang, required this.wide});
  final Lang lang;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _t(lang, 'road1'),
      _t(lang, 'road2'),
      _t(lang, 'road3'),
      _t(lang, 'road4'),
    ];
    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: EdgeInsets.symmetric(horizontal: wide ? 72 : 20, vertical: 84),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(lang, 'road_tag').toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Text(_t(lang, 'road_title'),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: wide ? 38 : 28,
                    fontWeight: FontWeight.w300,
                    height: 1.1)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var i = 0; i < steps.length; i++)
                  SizedBox(
                    width: wide ? 260 : double.infinity,
                    child: _StepCard(index: i + 1, title: steps[i]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.title});
  final int index;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
                color: AppTheme.gold, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$index',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.3))),
        ],
      ),
    );
  }
}

class _CTA extends StatelessWidget {
  const _CTA({required this.lang, required this.wide});
  final Lang lang;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 72 : 20, vertical: 84),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Text(_t(lang, 'cta_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: wide ? 34 : 26,
                    fontWeight: FontWeight.w300,
                    height: 1.1)),
            const SizedBox(height: 14),
            Text(
              _t(lang, 'cta_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamed('/app'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999))),
              child: Text(_t(lang, 'cta_app').toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.lang});
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Text(_t(lang, 'footer'),
          style: TextStyle(
              color: Colors.white.withValues(alpha: .35), fontSize: 12)),
    );
  }
}

Widget _badge(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: .06),
        border: Border.all(color: AppTheme.gold.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
    );

String _t(Lang l, String key) => _dict[key]?[l] ?? _dict[key]?[Lang.en] ?? key;

const _dict = {
  'hero_tag': {
    Lang.en: 'Founding partner program 2026',
    Lang.sk: 'Program zakladajúcich partnerov 2026',
    Lang.de: 'Gründungspartner-Programm 2026',
    Lang.es: 'Programa de socios fundadores 2026',
  },
  'hero_sub': {
    Lang.en: 'Private chauffeur platform · Swiss-grade precision',
    Lang.sk: 'Platforma súkromného šoféra · švajčiarska presnosť',
    Lang.de: 'Private-Chauffeur-Plattform · Schweizer Präzision',
    Lang.es: 'Plataforma de chofer privado · precisión suiza',
  },
  'hero_desc': {
    Lang.en:
        'Premium rides, dispatched with precision. Executive transport without marketplace chaos.',
    Lang.sk:
        'Prémiové jazdy s presným dispečingom. Exekutívny transport bez chaosu trhoviska.',
    Lang.de:
        'Premium-Fahrten mit präziser Disposition. Exekutiver Transport ohne Marktplatz-Chaos.',
    Lang.es:
        'Viajes premium con despacho preciso. Transporte ejecutivo sin caos de marketplace.',
  },
  'cta_demo': {
    Lang.en: 'View ride flow',
    Lang.sk: 'Zobraziť jazdný tok',
    Lang.de: 'Fahrtfluss ansehen',
    Lang.es: 'Ver flujo de viaje',
  },
  'cta_book': {
    Lang.en: 'Book premium ride',
    Lang.sk: 'Rezervovať prémiovú jazdu',
    Lang.de: 'Premium-Fahrt buchen',
    Lang.es: 'Reservar viaje premium',
  },
  'cta_app': {
    Lang.en: 'Open app',
    Lang.sk: 'Otvoriť aplikáciu',
    Lang.de: 'App öffnen',
    Lang.es: 'Abrir app',
  },
  'stat_1_title': {
    Lang.en: 'Zero',
    Lang.sk: 'Nula',
    Lang.de: 'Null',
    Lang.es: 'Cero'
  },
  'stat_1_desc': {
    Lang.en: 'Marketplace dependency',
    Lang.sk: 'Závislosť od trhovísk',
    Lang.de: 'Abhängigkeit von Marktplätzen',
    Lang.es: 'Dependencia de plataformas',
  },
  'stat_2_title': {
    Lang.en: 'Growing',
    Lang.sk: 'Rast',
    Lang.de: 'Wachstum',
    Lang.es: 'Crecimiento'
  },
  'stat_2_desc': {
    Lang.en: 'Premium mobility segment',
    Lang.sk: 'Prémiový segment mobility',
    Lang.de: 'Premium-Mobilitätssegment',
    Lang.es: 'Segmento de movilidad premium',
  },
  'stat_3_title': {
    Lang.en: '3 seats',
    Lang.sk: '3 miesta',
    Lang.de: '3 Plätze',
    Lang.es: '3 plazas'
  },
  'stat_3_desc': {
    Lang.en: 'Founding partner positions',
    Lang.sk: 'Miesta pre zakladajúcich partnerov',
    Lang.de: 'Gründungspartner-Positionen',
    Lang.es: 'Posiciones de socios fundadores',
  },
  'stat_4_title': {
    Lang.en: 'MVP',
    Lang.sk: 'MVP',
    Lang.de: 'MVP',
    Lang.es: 'MVP'
  },
  'stat_4_desc': {
    Lang.en: 'Active development 2026',
    Lang.sk: 'Aktívny vývoj 2026',
    Lang.de: 'Aktive Entwicklung 2026',
    Lang.es: 'Desarrollo activo 2026',
  },
  'features_tag': {
    Lang.en: 'The platform',
    Lang.sk: 'Platforma',
    Lang.de: 'Die Plattform',
    Lang.es: 'La plataforma',
  },
  'features_title': {
    Lang.en: 'Passenger, driver and ops in one clean flow',
    Lang.sk: 'Passenger, driver a ops v jednom čistom toku',
    Lang.de: 'Passagier, Fahrer und Ops in einem klaren Flow',
    Lang.es: 'Pasajero, conductor y operaciones en un flujo limpio',
  },
  'features_desc': {
    Lang.en:
        'A compact ride-hailing interface for booking, driver actions and operational control.',
    Lang.sk:
        'Kompaktné ride-hailing rozhranie pre rezervácie, akcie vodiča a prevádzkové riadenie.',
    Lang.de:
        'Eine kompakte Ride-Hailing-Oberfläche für Buchung, Fahreraktionen und operative Steuerung.',
    Lang.es:
        'Una interfaz compacta para reservas, acciones del conductor y control operativo.',
  },
  'feat1_title': {
    Lang.en: 'Booking flow',
    Lang.sk: 'Rezervačný tok',
    Lang.de: 'Buchungsablauf',
    Lang.es: 'Flujo de reservas'
  },
  'feat1_desc': {
    Lang.en: 'Clean pickup, dropoff, vehicle class and trip preview.',
    Lang.sk: 'Jasný výber odjazdu, cieľa, triedy vozidla a náhľadu jazdy.',
    Lang.de:
        'Klare Auswahl von Abholung, Ziel, Fahrzeugklasse und Fahrtvorschau.',
    Lang.es:
        'Selección clara de recogida, destino, clase de vehículo y vista previa.'
  },
  'feat2_title': {
    Lang.en: 'Driver console',
    Lang.sk: 'Konzola vodiča',
    Lang.de: 'Fahrer-Konsole',
    Lang.es: 'Consola del conductor'
  },
  'feat2_desc': {
    Lang.en: 'Online / offline state and live ride actions.',
    Lang.sk: 'Stav online/offline a živé akcie jazdy.',
    Lang.de: 'Online-/Offline-Status und Live-Fahrtaktionen.',
    Lang.es: 'Estado en línea / fuera de línea y acciones en vivo.'
  },
  'feat3_title': {
    Lang.en: 'Operations control',
    Lang.sk: 'Operačné ovládanie',
    Lang.de: 'Operationssteuerung',
    Lang.es: 'Control de operaciones'
  },
  'feat3_desc': {
    Lang.en: 'Live rides, online drivers and resolve actions in one place.',
    Lang.sk: 'Živé jazdy, online vodiči a resolve akcie na jednom mieste.',
    Lang.de: 'Live-Fahrten, Online-Fahrer und Resolve-Aktionen an einem Ort.',
    Lang.es:
        'Viajes en vivo, conductores online y acciones de resolución en un solo lugar.'
  },
  'feat4_title': {
    Lang.en: 'Four languages',
    Lang.sk: 'Štyri jazyky',
    Lang.de: 'Vier Sprachen',
    Lang.es: 'Cuatro idiomas'
  },
  'feat4_desc': {
    Lang.en: 'EN, SK, Swiss German and Spanish.',
    Lang.sk: 'EN, SK, švajčiarska nemčina a španielčina.',
    Lang.de: 'EN, SK, Schweizerdeutsch und Spanisch.',
    Lang.es: 'EN, SK, alemán suizo y español.'
  },
  'feat5_title': {
    Lang.en: 'Swiss-hosted data',
    Lang.sk: 'Dáta vo Švajčiarsku',
    Lang.de: 'Schweizer Hosting',
    Lang.es: 'Datos en Suiza'
  },
  'feat5_desc': {
    Lang.en:
        'Securely stored in Zurich (europe-west6) under strict Swiss protection standards.',
    Lang.sk:
        'Bezpečne uložené v Zürichu (europe-west6) pod najprísnejšou ochranou.',
    Lang.de:
        'Sicher gehostet in Zürich (europe-west6) unter strengen Schweizer Datenschutzstandards.',
    Lang.es:
        'Almacenado de forma segura en Zúrich (europe-west6) con los estándares más estrictos.'
  },
  'road_tag': {
    Lang.en: 'Roadmap',
    Lang.sk: 'Roadmapa',
    Lang.de: 'Roadmap',
    Lang.es: 'Hoja de ruta'
  },
  'road_title': {
    Lang.en: 'From MVP to Swiss launch',
    Lang.sk: 'Od MVP po švajčiarsky launch',
    Lang.de: 'Vom MVP zum Schweizer Start',
    Lang.es: 'Del MVP al lanzamiento suizo',
  },
  'road1': {
    Lang.en: 'Foundation',
    Lang.sk: 'Základy',
    Lang.de: 'Grundlage',
    Lang.es: 'Fundación'
  },
  'road2': {
    Lang.en: 'MVP development',
    Lang.sk: 'Vývoj MVP',
    Lang.de: 'MVP-Entwicklung',
    Lang.es: 'Desarrollo del MVP'
  },
  'road3': {
    Lang.en: 'Swiss pilot',
    Lang.sk: 'Pilot vo Švajčiarsku',
    Lang.de: 'Schweizer Pilot',
    Lang.es: 'Piloto suizo'
  },
  'road4': {
    Lang.en: 'Rollout',
    Lang.sk: 'Rozšírenie',
    Lang.de: 'Rollout',
    Lang.es: 'Despliegue'
  },
  'cta_title': {
    Lang.en: 'Own your brand. Own your clients. Own your data.',
    Lang.sk: 'Vlastnite značku. Vlastnite klientov. Vlastnite dáta.',
    Lang.de: 'Eigene Marke. Eigene Kunden. Eigene Daten.',
    Lang.es: 'Su marca. Sus clientes. Sus datos.',
  },
  'cta_desc': {
    Lang.en:
        'Built for premium transport operators who want a polished digital front door and a clear path to scale.',
    Lang.sk:
        'Vytvorené pre prémiových dopravcov, ktorí chcú vyladený digitálny vstup a jasnú cestu rastu.',
    Lang.de:
        'Gebaut für Premium-Transportanbieter mit poliertem digitalem Eingang und klarer Skalierung.',
    Lang.es:
        'Diseñado para operadores premium con una entrada digital pulida y una ruta clara para crecer.',
  },
  'footer': {
    Lang.en: '© 2026 GoldTaxi · Premium mobility platform',
    Lang.sk: '© 2026 GoldTaxi · Prémiová mobilná platforma',
    Lang.de: '© 2026 GoldTaxi · Premium-Mobilitätsplattform',
    Lang.es: '© 2026 GoldTaxi · Plataforma de movilidad premium',
  },
};
