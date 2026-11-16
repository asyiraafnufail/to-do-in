import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

// Alias untuk kemudahan onboarding tim sesuai README.md
String get kDefaultPbUrl => AppConstants.pbUrl;

// Persistent client instance; starts with in-memory fallback, upgraded via initPb()
PocketBase pb = PocketBase(AppConstants.pbUrl);

/// Initializes persistent authentication via SharedPreferences and AsyncAuthStore.
Future<void> initPb() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final store = AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth', data),
      clear: () async => prefs.remove('pb_auth'),
      initial: prefs.getString('pb_auth'),
    );
    pb = PocketBase(AppConstants.pbUrl, authStore: store);
  } catch (e) {
    debugPrint('initPb persistence fallback: $e');
  }
}

// Notifiers for realtime reactive updates across tabs
final feedRefreshNotifier = ValueNotifier<int>(0);
final savedRefreshNotifier = ValueNotifier<int>(0);
final listingsRefreshNotifier = ValueNotifier<int>(0);
final todoRefreshNotifier = ValueNotifier<int>(0);

/// Initializes PocketBase SSE realtime subscriptions.
/// Subscribes to collection changes and updates UI notifiers automatically.
void initPbRealtime() {
  try {
    pb.collection('posts').subscribe('*', (_) {
      feedRefreshNotifier.value++;
    });
    pb.collection('social_actions').subscribe('*', (_) {
      savedRefreshNotifier.value++;
      feedRefreshNotifier.value++;
    });
    pb.collection('listings').subscribe('*', (_) {
      listingsRefreshNotifier.value++;
    });
    pb.collection('user_todos').subscribe('*', (_) {
      todoRefreshNotifier.value++;
    });
  } catch (_) {
    // Realtime connection silently falls back to pull-to-refresh if offline
  }
}
