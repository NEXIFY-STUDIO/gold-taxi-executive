class BrandConfig {
  const BrandConfig({
    this.name = const String.fromEnvironment(
      'WHITELABEL_BRAND_NAME',
      defaultValue: 'GoldTaxi',
    ),
    this.operatorLabel = const String.fromEnvironment(
      'WHITELABEL_OPERATOR_LABEL',
      defaultValue: 'Private chauffeur platform',
    ),
    this.marketLabel = const String.fromEnvironment(
      'WHITELABEL_MARKET_LABEL',
      defaultValue: 'Swiss premium mobility',
    ),
    this.poweredBy = const String.fromEnvironment(
      'WHITELABEL_POWERED_BY',
      defaultValue: 'Powered by GoldTaxi',
    ),
  });

  final String name;
  final String operatorLabel;
  final String marketLabel;
  final String poweredBy;

  String get displayName => _fallback(name, 'GoldTaxi');

  String get displayOperatorLabel =>
      _fallback(operatorLabel, 'Private chauffeur platform');

  String get displayMarketLabel =>
      _fallback(marketLabel, 'Swiss premium mobility');

  String get displayPoweredBy => _fallback(poweredBy, 'Powered by GoldTaxi');

  String get appTitle => '$displayName · Premium Mobility';

  static String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
