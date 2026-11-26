import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../constants/app_constants.dart';
import '../services/pb_client.dart';
import 'auth_repository.dart';

class KycRepository {
  const KycRepository();

  Future<RecordModel?> getLatestUserRequest(String userId) async {
    final res = await pb.collection('kyc_requests').getList(
          filter: pb.filter('user = {:uid}', {'uid': userId}),
          sort: '-created',
          perPage: 1,
        );
    return res.items.isNotEmpty ? res.items.first : null;
  }

  Future<List<RecordModel>> getAllRequests() {
    return pb.collection('kyc_requests').getFullList(
          sort: '-created',
          expand: 'user',
        );
  }

  Future<RecordModel> submitRequest({
    required String userId,
    required String note,
    required List<http.MultipartFile> files,
  }) {
    return pb.collection('kyc_requests').create(
      body: {
        'user': userId,
        'status': 'pending',
        'admin_note': note,
      },
      files: files,
    );
  }

  Future<void> approveRequest(RecordModel request) async {
    final userId = request.getStringValue('user');
    await pb.collection('kyc_requests').update(request.id, body: {
      'status': 'approved',
      'admin_note': 'Disetujui oleh Admin pada ${DateTime.now().toLocal()}',
    });
    if (userId.isNotEmpty) {
      await authRepo.setVerifiedHost(userId, true);
    }
  }

  Future<void> rejectRequest(RecordModel request, String reason) async {
    final userId = request.getStringValue('user');
    await pb.collection('kyc_requests').update(request.id, body: {
      'status': 'rejected',
      'admin_note': reason,
    });
    if (userId.isNotEmpty) {
      await authRepo.setVerifiedHost(userId, false);
    }
  }

  String getProtectedDocumentUrl(RecordModel kyc, String filename) {
    return '${AppConstants.pbUrl}/api/files/kyc_requests/${kyc.id}/$filename?token=${pb.authStore.token}';
  }
}

const kycRepo = KycRepository();
