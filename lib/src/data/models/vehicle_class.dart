import 'package:flutter/material.dart';

enum VehicleClass {
  standard,
  comfort,
  premium,
  van;

  String get label {
    return switch (this) {
      VehicleClass.standard => 'Standard',
      VehicleClass.comfort => 'Comfort',
      VehicleClass.premium => 'Premium',
      VehicleClass.van => 'Van VIP',
    };
  }

  String get description {
    return switch (this) {
      VehicleClass.standard => 'Everyday city ride',
      VehicleClass.comfort => 'Better car, more space',
      VehicleClass.premium => 'Business chauffeur class',
      VehicleClass.van => 'Group transfer, airport VIP',
    };
  }

  double get baseFare {
    return switch (this) {
      VehicleClass.standard => 3.20,
      VehicleClass.comfort => 4.80,
      VehicleClass.premium => 8.50,
      VehicleClass.van => 12.00,
    };
  }

  double get pricePerKm {
    return switch (this) {
      VehicleClass.standard => 0.95,
      VehicleClass.comfort => 1.25,
      VehicleClass.premium => 1.90,
      VehicleClass.van => 2.35,
    };
  }

  double get pricePerMinute {
    return switch (this) {
      VehicleClass.standard => 0.18,
      VehicleClass.comfort => 0.24,
      VehicleClass.premium => 0.38,
      VehicleClass.van => 0.44,
    };
  }

  double get minimumFare {
    return switch (this) {
      VehicleClass.standard => 6.00,
      VehicleClass.comfort => 8.00,
      VehicleClass.premium => 14.00,
      VehicleClass.van => 18.00,
    };
  }

  Color get accentColor {
    return switch (this) {
      VehicleClass.standard => const Color(0xFFBFC3C7),
      VehicleClass.comfort => const Color(0xFFD6B65C),
      VehicleClass.premium => const Color(0xFFEBCB73),
      VehicleClass.van => const Color(0xFF95D5B2),
    };
  }
}
