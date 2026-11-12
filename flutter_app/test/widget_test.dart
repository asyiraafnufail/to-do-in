import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/services/pb_client.dart';
import 'package:flutter_app/core/utils/date_formatter.dart';
import 'package:flutter_app/features/admin/admin_dashboard_screen.dart';
import 'package:flutter_app/features/explore/explore_screen.dart';
import 'package:flutter_app/features/feed/widgets/post_card.dart';
import 'package:flutter_app/features/marketplace/widgets/listing_card.dart';
import 'package:flutter_app/features/profile/profile_screen.dart';
import 'package:flutter_app/features/todo/todo_screen.dart';
import 'package:flutter_app/main.dart';

String _fakeJwt() {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final payload = base64Url.encode(utf8.encode('{"exp":9999999999}'));
  return '$header.$payload.sig';
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    pb.authStore.clear();
  });

  group('DateFormatter', () {
    test('handles empty or null gracefully', () {
      expect(DateFormatter.timeAgo(null), '');
      expect(DateFormatter.timeAgo(''), '');
      expect(DateFormatter.timeAgo('invalid-date'), '');
    });

    test('formats recent dates to Indonesian relative strings', () {
      final now = DateTime.now().toUtc();
      expect(DateFormatter.timeAgo(now.toIso8601String()), 'Baru saja');

      final minAgo = now.subtract(const Duration(minutes: 5));
      expect(DateFormatter.timeAgo(minAgo.toIso8601String()), '5 mnt lalu');

      final hourAgo = now.subtract(const Duration(hours: 3));
      expect(DateFormatter.timeAgo(hourAgo.toIso8601String()), '3 jam lalu');

      final dayAgo = now.subtract(const Duration(days: 2));
      expect(DateFormatter.timeAgo(dayAgo.toIso8601String()), '2 hr lalu');

      expect(DateFormatter.timeAgo('2025-01-15T10:00:00Z'), '15 Jan 2025');
    });
  });

  testWidgets('App boots to Feed shell', (WidgetTester tester) async {
    await tester.pumpWidget(const TodoinApp());
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
  });

  testWidgets('TodoScreen syncs automatically with pb.authStore changes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TodoScreen()));
    await tester.pump();

    expect(find.text('Rencana Perjalanan Pribadi'), findsOneWidget);

    pb.authStore.save(_fakeJwt(), RecordModel({'id': 'u1'}));
    await tester.pumpAndSettle();

    expect(find.text('Rencana Perjalanan Pribadi'), findsNothing);
    expect(find.text('Belum ada aktivitas disimpan'), findsOneWidget);

    pb.authStore.clear();
    await tester.pumpAndSettle();

    expect(find.text('Rencana Perjalanan Pribadi'), findsOneWidget);
  });

  testWidgets('PostCard renders title, Live GPS badge, and author recommendations',
      (WidgetTester tester) async {
    final mockPost = RecordModel({
      'id': 'post_test_1',
      'title': 'Eksplor Tebing Breksi Jogja',
      'content':
          'Tempat bekas tambang kapur yang disulap jadi taman wisata indah.',
      'category': 'Alam',
      'place_name': 'Tebing Breksi',
      'city': 'Sleman',
      'province': 'DI Yogyakarta',
      'is_live_gps': true,
      'lat_approx': -7.7812,
      'lng_approx': 110.5045,
      'is_edited': true,
      'created': DateTime.now().toUtc().toIso8601String(),
      'todo_items': [
        'Foto di pahatan dinding naga',
        'Cicip es kelapa muda di amfiteater',
      ],
      'expand': {
        'author': {
          'id': 'user_author_1',
          'name': 'Budi Santoso',
          'is_verified_host': true,
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostCard(post: mockPost),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Eksplor Tebing Breksi Jogja'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.textContaining('(Diedit)'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.text('Live GPS'), findsOneWidget);
    expect(find.text('To-Do Rekomendasi Penulis (2)'), findsOneWidget);
    expect(find.text('Foto di pahatan dinding naga'), findsOneWidget);
    expect(find.text('Cicip es kelapa muda di amfiteater'), findsOneWidget);
    expect(find.text('+ To-Do'), findsNWidgets(2));
  });

  testWidgets('ListingCard renders price formatting, category pill, and verified host',
      (WidgetTester tester) async {
    final mockListing = RecordModel({
      'id': 'listing_test_1',
      'title': 'Sewa Honda Scoopy 2024 Dekat Tugu',
      'type': 'vehicle',
      'price': 85000,
      'price_unit': 'day',
      'city': 'Kota Yogyakarta',
      'province': 'DI Yogyakarta',
      'images': <String>[],
      'expand': {
        'owner': {
          'id': 'user_host_1',
          'name': 'Rental Mas Joko',
          'is_verified_host': true,
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListingCard(listing: mockListing),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sewa Honda Scoopy 2024 Dekat Tugu'), findsOneWidget);
    expect(find.text('Sewa Kendaraan'), findsOneWidget);
    expect(find.textContaining('85.000'), findsOneWidget);
    expect(find.textContaining('/ hari'), findsOneWidget);
    expect(find.text('Rental Mas Joko'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.text('Penuh'), findsNothing);

    final fullListing = RecordModel({
      ...mockListing.toJson(),
      'is_available': false,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListingCard(listing: fullListing),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Penuh'), findsOneWidget);
  });

  testWidgets('ExploreScreen switches cleanly between Cerita and Layanan tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Cerita & To-Do'), findsOneWidget);
    expect(find.text('Sewa & Layanan'), findsOneWidget);
    expect(find.text('Layanan Lokal Terverifikasi'), findsOneWidget);

    await tester.tap(find.text('Sewa & Layanan'));
    await tester.pumpAndSettle();

    expect(find.text('Semua Jenis'), findsOneWidget);
    expect(find.text('Kendaraan'), findsOneWidget);
    expect(find.text('Open Trip'), findsOneWidget);
    expect(find.text('Homestay'), findsOneWidget);
  });

  testWidgets('ProfileScreen updates tabs safely when host status changes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke Profil Anda'), findsOneWidget);

    pb.authStore.save(
      _fakeJwt(),
      RecordModel({
        'id': 'u1',
        'username': 'traveler1',
        'name': 'Traveler Satu',
        'is_verified_host': false,
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daftar Jadi Local Host Terverifikasi'), findsOneWidget);
    expect(find.text('Layanan (0)'), findsNothing);

    pb.authStore.save(
      _fakeJwt(),
      RecordModel({
        'id': 'u1',
        'username': 'traveler1',
        'name': 'Traveler Satu',
        'is_verified_host': true,
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daftar Jadi Local Host Terverifikasi'), findsNothing);
    expect(find.text('Layanan (0)'), findsOneWidget);
  });

  test('initPb restores persistent login session from SharedPreferences', () async {
    final mockAuth = jsonEncode({
      'token': _fakeJwt(),
      'model': {
        'id': 'persisted_u1',
        'username': 'persisted_user',
        'name': 'User Tersimpan',
      },
    });

    SharedPreferences.setMockInitialValues({'pb_auth': mockAuth});
    await initPb();

    expect(pb.authStore.isValid, isTrue);
    expect(pb.authStore.record?.id, 'persisted_u1');
    expect(pb.authStore.record?.getStringValue('username'), 'persisted_user');

    pb.authStore.clear();
    expect(pb.authStore.isValid, isFalse);
  });

  testWidgets('AdminDashboardScreen shows login when unauthenticated and switches on superuser auth',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Login Admin Panel'), findsOneWidget);
    expect(find.text('Panel Moderasi & KYC'), findsOneWidget);

    // Save superuser session
    pb.authStore.save(
      _fakeJwt(),
      RecordModel({
        'id': 'admin_1',
        'collectionName': '_superusers',
        'email': 'admin@todoin.id',
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Panel'), findsOneWidget);
    expect(find.text('KYC Host'), findsOneWidget);
  });
}
