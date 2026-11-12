// ignore_for_file: avoid_print

import 'package:pocketbase/pocketbase.dart';

void main(List<String> args) async {
  final baseUrl = args.isNotEmpty ? args[0] : 'http://127.0.0.1:8090';
  print('====================================================');
  print('  TO-DO-IN POCKETBASE SEEDING TEST ACCOUNTS');
  print('  Target URL: $baseUrl');
  print('====================================================\n');

  final pb = PocketBase(baseUrl);

  // 1. Verifikasi koneksi server
  try {
    final health = await pb.health.check();
    print('✓ Server aktif (HTTP ${health.code})');
  } catch (e) {
    print('✗ Gagal terhubung ke $baseUrl: $e');
    print('  Pastikan PocketBase sedang berjalan: ./pocketbase serve\n');
    return;
  }

  // 2. Info Akun Superuser & Pembuatan di collection users
  print('\n[1/4] Kredensial Superuser & Akun Admin:');
  print('  Email    : admin@todoin.id');
  print('  Password : admin123456');

  // Coba login sebagai superuser
  bool isSuperuserAuthed = false;
  try {
    await pb.collection('_superusers').authWithPassword('admin@todoin.id', 'admin123456');
    isSuperuserAuthed = true;
    print('  ✓ Superuser root login berhasil terverifikasi');
  } catch (_) {
    try {
      await pb.send('/api/admins/auth-with-password', method: 'POST', body: {
        'identity': 'admin@todoin.id',
        'password': 'admin123456',
      });
      isSuperuserAuthed = true;
      print('  ✓ Legacy admin root login berhasil terverifikasi');
    } catch (_) {
      print('  ! Akun superuser belum terdaftar di PocketBase internal table.');
      print('    Jalankan perintah ini di VPS:');
      print('      cd /var/www/todoin/pocketbase');
      print('      ./pocketbase superuser create admin@todoin.id admin123456');
    }
  }

  // Daftarkan admin@todoin.id ke dalam collection users
  try {
    final existingAdminUser = await pb.collection('users').getFirstListItem('email = "admin@todoin.id" || username = "admin"');
    print('  ✓ Akun Admin sudah terdaftar di collection users (ID: ${existingAdminUser.id})');
  } catch (_) {
    try {
      final newAdminUser = await pb.collection('users').create(body: {
        'email': 'admin@todoin.id',
        'password': 'admin123456',
        'passwordConfirm': 'admin123456',
        'username': 'admin',
        'name': 'Administrator Todoin',
        'bio': 'System Administrator & Moderator',
        'contact_privacy': 'public',
        'is_verified_host': true,
      });
      print('  ✓ Akun Admin berhasil dibuat di collection users (ID: ${newAdminUser.id})');
    } catch (e) {
      print('  ! Catatan pembuatan admin di collection users: $e');
    }
  }

  // 3. Buat / Update Akun Local Guide Terverifikasi
  print('\n[2/4] Menyiapkan Akun Local Guide Terverifikasi:');
  const guideEmail = 'guide@todoin.id';
  const guidePassword = 'guide123456';
  const guideUsername = 'guide_jogja';

  String? guideId;
  try {
    final existingGuide = await pb.collection('users').getFirstListItem('email = "$guideEmail" || username = "$guideUsername"');
    guideId = existingGuide.id;
    print('  ✓ Akun Local Guide sudah ada (ID: $guideId)');

    // Pastikan status is_verified_host = true
    if (isSuperuserAuthed) {
      await pb.collection('users').update(guideId, body: {
        'name': 'Mas Joko (Jogja Guide)',
        'whatsapp': '6281234567890',
        'bio': 'Local guide terverifikasi Jogja. Rental motor, open trip candi & kuliner malam.',
        'is_verified_host': true,
      });
    } else {
      // Coba update via auth akun guide sendiri jika diperbolehkan rule
      try {
        final guidePb = PocketBase(baseUrl);
        await guidePb.collection('users').authWithPassword(guideEmail, guidePassword);
        await guidePb.collection('users').update(guideId, body: {'is_verified_host': true});
      } catch (_) {}
    }
  } catch (_) {
    // Buat akun baru
    try {
      final newGuide = await pb.collection('users').create(body: {
        'email': guideEmail,
        'password': guidePassword,
        'passwordConfirm': guidePassword,
        'username': guideUsername,
        'name': 'Mas Joko (Jogja Guide)',
        'whatsapp': '6281234567890',
        'bio': 'Local guide terverifikasi Jogja. Rental motor, open trip candi & kuliner malam.',
        'contact_privacy': 'public',
        'is_verified_host': true,
      });
      guideId = newGuide.id;
      print('  ✓ Akun Local Guide berhasil dibuat (ID: $guideId)');
    } catch (e) {
      print('  ✗ Gagal membuat akun guide: $e');
    }
  }

  // Verifikasi akhir nilai is_verified_host pada database
  if (guideId != null) {
    try {
      final check = await pb.collection('users').getOne(guideId);
      final isVerified = check.getBoolValue('is_verified_host');
      if (isVerified) {
        print('  ✓ Status is_verified_host = true TERVERIFIKASI AKTIF di database');
      } else {
        print('  ! PERINGATAN: is_verified_host masih bernilai FALSE di database.');
        print('    PocketBase mengunci field ini dari user biasa.');
        print('    Solusi: Buat superuser di VPS terlebih dahulu:');
        print('      cd /var/www/todoin/pocketbase');
        print('      ./pocketbase superuser create admin@todoin.id admin123456');
        print('    Lalu jalankan ulang skrip seed ini, atau centang manual di Admin Web:');
        print('      $baseUrl/_/ -> users -> guide@todoin.id -> is_verified_host');
      }
    } catch (_) {}
  }

  // 4. Buat Akun Traveler Reguler (untuk tes pengajuan KYC)
  print('\n[3/4] Menyiapkan Akun Traveler Reguler (Tes Member):');
  const travelerEmail = 'traveler@todoin.id';
  const travelerPassword = 'traveler123456';
  const travelerUsername = 'budi_petualang';

  try {
    final existingTraveler = await pb.collection('users').getFirstListItem('email = "$travelerEmail" || username = "$travelerUsername"');
    print('  ✓ Akun Traveler sudah ada (ID: ${existingTraveler.id})');
  } catch (_) {
    try {
      final newTraveler = await pb.collection('users').create(body: {
        'email': travelerEmail,
        'password': travelerPassword,
        'passwordConfirm': travelerPassword,
        'username': travelerUsername,
        'name': 'Budi Santoso',
        'bio': 'Pecinta alam & penikmat kopi senja.',
        'contact_privacy': 'public',
        'is_verified_host': false,
      });
      print('  ✓ Akun Traveler berhasil dibuat (ID: ${newTraveler.id})');
    } catch (e) {
      print('  ✗ Gagal membuat akun traveler: $e');
    }
  }

  // Ringkasan akun
  print('\n====================================================');
  print('  SELESAI! KREDENSIAL UNTUK TESTING APLIKASI:');
  print('====================================================');
  print('1. SUPERUSER / ADMIN PANEL:');
  print('   - Masuk lewat ikon 🛡️ di tab Profil.');
  print('   - Email    : admin@todoin.id');
  print('   - Password : admin123456');
  print('');
  print('2. AKUN LOCAL GUIDE TERVERIFIKASI:');
  print('   - Email    : guide@todoin.id');
  print('   - Password : guide123456');
  print('   - Fitur    : Punya tab "Layanan" & bisa buat listing sewa/trip.');
  print('');
  print('3. AKUN TRAVELER BIASA (MEMBER REGULER):');
  print('   - Email    : traveler@todoin.id');
  print('   - Password : traveler123456');
  print('   - Fitur    : Simpan To-Do & tes ajukan verifikasi KYC Host.');
  print('====================================================\n');
}
