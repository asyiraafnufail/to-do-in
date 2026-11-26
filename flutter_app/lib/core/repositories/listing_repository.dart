import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_client.dart';

class ListingRepository {
  const ListingRepository();

  Future<ResultList<RecordModel>> getListings({
    int page = 1,
    int perPage = 30,
    String? province,
    String? type,
    String? query,
    String? ownerId,
    bool? onlyAvailable,
  }) {
    final parts = <String>[];
    if (ownerId != null && ownerId.isNotEmpty) {
      parts.add(pb.filter('owner = {:id}', {'id': ownerId}));
    }
    if (onlyAvailable == true) {
      parts.add('is_available = true');
    }
    if (province != null && province.isNotEmpty) {
      parts.add(pb.filter('province = {:prov}', {'prov': province}));
    }
    if (type != null && type.isNotEmpty) {
      parts.add(pb.filter('type = {:t}', {'t': type}));
    }
    if (query != null && query.trim().isNotEmpty) {
      parts.add(
          pb.filter('(title ~ {:q} || city ~ {:q})', {'q': query.trim()}));
    }

    return pb.collection('listings').getList(
          page: page,
          perPage: perPage,
          sort: '-created',
          expand: 'owner',
          filter: parts.join(' && '),
        );
  }

  Future<RecordModel> getListing(String listingId) {
    return pb.collection('listings').getOne(listingId, expand: 'owner');
  }

  Future<RecordModel> createListing({
    required Map<String, dynamic> body,
    List<http.MultipartFile> files = const [],
  }) async {
    final created = await pb.collection('listings').create(
          body: body,
          files: files,
        );
    listingsRefreshNotifier.value++;
    return created;
  }

  Future<RecordModel> updateListing(
    String listingId, {
    required Map<String, dynamic> body,
    List<http.MultipartFile> files = const [],
  }) async {
    final updated = await pb.collection('listings').update(
          listingId,
          body: body,
          files: files,
        );
    listingsRefreshNotifier.value++;
    return updated;
  }

  Future<RecordModel> setAvailability(String listingId, bool isAvailable) async {
    final updated = await pb.collection('listings').update(
      listingId,
      body: {'is_available': isAvailable},
      expand: 'owner',
    );
    listingsRefreshNotifier.value++;
    return updated;
  }

  Future<void> deleteListing(String listingId) async {
    await pb.collection('listings').delete(listingId);
    listingsRefreshNotifier.value++;
  }
}

const listingRepo = ListingRepository();
