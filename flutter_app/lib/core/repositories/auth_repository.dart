import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_client.dart';

class AuthRepository {
  const AuthRepository();

  bool get isAuthenticated => pb.authStore.isValid;
  RecordModel? get currentUser => pb.authStore.record;
  String? get currentUserId => pb.authStore.record?.id;
  String get token => pb.authStore.token;
  Stream<AuthStoreEvent> get onAuthChanged => pb.authStore.onChange;

  bool isSuperuserOrAdmin([RecordModel? record]) {
    final rec = record ?? currentUser;
    if (rec == null) return false;
    final collectionName = rec.collectionName;
    final data = rec.toJson();
    return collectionName == '_superusers' ||
        collectionName == 'admins' ||
        data['collectionName'] == '_superusers' ||
        data['collectionName'] == 'admins' ||
        rec.getBoolValue('is_admin') ||
        rec.getStringValue('username') == 'admin' ||
        rec.getStringValue('email').startsWith('admin@');
  }

  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) async {
    await pb.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
      'username': username,
      'name': name,
      'contact_privacy': 'public',
    });
    await pb.collection('users').authWithPassword(email, password);
    try {
      await pb.collection('users').requestVerification(email);
    } catch (_) {}
  }

  /// Login reguler maupun superuser. Mengembalikan `true` jika akun adalah admin/superuser.
  Future<bool> login(String email, String password) async {
    bool isAdmin = await _trySuperuserAuth(email, password);
    if (!isAdmin) {
      final auth =
          await pb.collection('users').authWithPassword(email, password);
      if (isSuperuserOrAdmin(auth.record)) {
        isAdmin = true;
      }
    }
    return isAdmin;
  }

  /// Login khusus halaman Admin Panel. Melempar error jika akun bukan administrator.
  Future<void> loginAdminOnly(String email, String password) async {
    final authedSuper = await _trySuperuserAuth(email, password);
    if (authedSuper) return;

    final userAuth =
        await pb.collection('users').authWithPassword(email, password);
    if (!isSuperuserOrAdmin(userAuth.record)) {
      pb.authStore.clear();
      throw 'Akun ini bukan administrator.';
    }
  }

  Future<bool> _trySuperuserAuth(String email, String password) async {
    try {
      await pb.collection('_superusers').authWithPassword(email, password);
      return pb.authStore.isValid;
    } catch (_) {
      try {
        final res = await pb.send(
          '/api/admins/auth-with-password',
          method: 'POST',
          body: {'identity': email, 'password': password},
        );
        if (res is Map && res['token'] != null) {
          final token = res['token'] as String;
          final adminData = (res['admin'] as Map<String, dynamic>?) ?? {};
          pb.authStore.save(
            token,
            RecordModel({
              ...adminData,
              'id': adminData['id'] ?? 'admin',
              'email': email,
              'collectionName': '_superusers',
            }),
          );
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> loginWithGoogle(
      Future<void> Function(Uri url) urlLauncher) async {
    await pb.collection('users').authWithOAuth2('google', urlLauncher);
  }

  Future<void> requestPasswordReset(String email) async {
    await pb.collection('users').requestPasswordReset(email);
  }

  Future<void> requestVerification(String email) async {
    await pb.collection('users').requestVerification(email);
  }

  Future<void> refreshAuth() async {
    await pb.collection('users').authRefresh();
  }

  void logout() {
    pb.authStore.clear();
  }

  Future<RecordModel> getUser(String userId) {
    return pb.collection('users').getOne(userId);
  }

  Future<int> countUsers() async {
    final res = await pb.collection('users').getList(perPage: 1);
    return res.totalItems;
  }

  Future<RecordModel> updateProfile({
    required String userId,
    required String name,
    required String bio,
    required String whatsapp,
    required String instagram,
    required String contactPrivacy,
    List<http.MultipartFile> files = const [],
  }) async {
    final updated = await pb.collection('users').update(
      userId,
      body: {
        'name': name,
        'bio': bio,
        'whatsapp': whatsapp,
        'instagram': instagram,
        'contact_privacy': contactPrivacy,
      },
      files: files,
    );
    pb.authStore.save(pb.authStore.token, updated);
    return updated;
  }

  Future<void> setVerifiedHost(String userId, bool isVerified) async {
    await pb.collection('users').update(userId, body: {
      'is_verified_host': isVerified,
    });
  }
}

const authRepo = AuthRepository();
