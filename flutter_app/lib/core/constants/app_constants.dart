class AppConstants {
  AppConstants._();

  // URL PocketBase Backend:
  // Mengarah ke VPS Contabo (https://pb-dev.todoin.id).
  // Override via --dart-define=PB_URL=... saat ingin mengarahkan ke lokal atau environment lain.
  static String get pbUrl {
    const fromEnv = String.fromEnvironment('PB_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    return 'https://pb-dev.todoin.id';
  }

  static const List<String> postCategories = [
    'Kuliner',
    'Alam',
    'Budaya',
    'Hidden Gem',
    'Penginapan',
  ];

  static const List<String> provinces = [
    'Aceh',
    'Bali',
    'Banten',
    'Bengkulu',
    'DI Yogyakarta',
    'DKI Jakarta',
    'Gorontalo',
    'Jambi',
    'Jawa Barat',
    'Jawa Tengah',
    'Jawa Timur',
    'Kalimantan Barat',
    'Kalimantan Selatan',
    'Kalimantan Tengah',
    'Kalimantan Timur',
    'Kalimantan Utara',
    'Kepulauan Bangka Belitung',
    'Kepulauan Riau',
    'Lampung',
    'Maluku',
    'Maluku Utara',
    'Nusa Tenggara Barat',
    'Nusa Tenggara Timur',
    'Papua',
    'Papua Barat',
    'Papua Barat Daya',
    'Papua Pegunungan',
    'Papua Selatan',
    'Papua Tengah',
    'Riau',
    'Sulawesi Barat',
    'Sulawesi Selatan',
    'Sulawesi Tengah',
    'Sulawesi Tenggara',
    'Sulawesi Utara',
    'Sumatera Barat',
    'Sumatera Selatan',
    'Sumatera Utara',
  ];
}
