enum AppUserRole {
  passenger,
  driver,
  admin;

  static AppUserRole fromBackendValue(Object? value) {
    switch (value?.toString()) {
      case 'driver':
        return AppUserRole.driver;
      case 'admin':
      case 'ops':
        return AppUserRole.admin;
      default:
        return AppUserRole.passenger;
    }
  }

  bool get canAccessDriverTools => this == AppUserRole.driver;

  bool get canAccessOpsTools => this == AppUserRole.admin;

  List<int> get visibleShellIndices => [
        0,
        if (canAccessDriverTools) 1,
        if (canAccessOpsTools) 2,
      ];
}
