import 'package:flutter/material.dart';

class GoldTokens {
  const GoldTokens._();

  static const Color blackBase = Color(0xFF050505);
  static const Color blackElevated = Color(0xFF0E0E10);
  static const Color blackPanel = Color(0xFF151510);
  static const Color goldPrimary = Color(0xFFD7A84F);
  static const Color goldBright = Color(0xFFF2C86B);
  static const Color goldDeep = Color(0xFF9C7A34);
  static const Color textPrimary = Color(0xFFE8E8EA);
  static const Color textMuted = Color(0xFF8E8A7C);
  static const Color lineSoft = Color(0x1FFFFFFF);

  static const Color success = Color(0xFF62D394);
  static const Color warning = Color(0xFFE5A84A);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF7DB7FF);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldBright, goldPrimary, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blackGradient = LinearGradient(
    colors: [blackElevated, blackBase],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const String fontFamily = 'Plus Jakarta Sans';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.02,
    letterSpacing: 0,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.14,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0,
  );

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  static const double radiusCard = 24;
  static const double radiusButton = 16;
  static const double radiusPill = 999;
}
