import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';

class AdminPostsModerationTab extends StatelessWidget {
  final List<RecordModel> posts;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onDeletePost;

  const AdminPostsModerationTab({
    super.key,
    required this.posts,
    required this.onRefresh,
    required this.onDeletePost,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final post = posts[idx];
          final title = post.getStringValue('title');
          final author = post.get<RecordModel?>('expand.author');
          final authorName = author?.getStringValue('name') ??
              author?.getStringValue('username') ??
              'Penulis';
          final city = post.getStringValue('city');
          final created = post.getStringValue('created');

          return Card(
            child: ListTile(
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Oleh $authorName • $city • ${DateFormatter.timeAgo(created)}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Hapus Postingan',
                onPressed: () => onDeletePost(post.id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminListingsModerationTab extends StatelessWidget {
  final List<RecordModel> listings;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onDeleteListing;

  const AdminListingsModerationTab({
    super.key,
    required this.listings,
    required this.onRefresh,
    required this.onDeleteListing,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: listings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final listing = listings[idx];
          final title = listing.getStringValue('title');
          final owner = listing.get<RecordModel?>('expand.owner');
          final ownerName = owner?.getStringValue('name') ??
              owner?.getStringValue('username') ??
              'Host';
          final city = listing.getStringValue('city');
          final price = listing.getIntValue('price');
          final priceUnit = listing.getStringValue('price_unit');

          return Card(
            child: ListTile(
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Rp $price / $priceUnit • $ownerName ($city)',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Hapus Listing',
                onPressed: () => onDeleteListing(listing.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
