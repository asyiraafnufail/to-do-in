import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/feed/create_post_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/feed/post_detail_screen.dart';
import '../../features/host/kyc_submission_screen.dart';
import '../../features/marketplace/create_listing_screen.dart';
import '../../features/marketplace/listing_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/todo/todo_screen.dart';
import 'main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/feed',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/feed',
              builder: (context, state) => const FeedScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/todo',
              builder: (context, state) => const TodoScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CreatePostScreen(
        initialPost: state.extra as RecordModel?,
      ),
    ),
    GoRoute(
      path: '/post/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return PostDetailScreen(postId: id);
      },
    ),
    GoRoute(
      path: '/user/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return UserProfileScreen(userId: id);
      },
    ),
    GoRoute(
      path: '/listing/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ListingDetailScreen(listingId: id);
      },
    ),
    GoRoute(
      path: '/create-listing',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => CreateListingScreen(
        initialListing: state.extra as RecordModel?,
      ),
    ),
    GoRoute(
      path: '/kyc',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const KycSubmissionScreen(),
    ),
    GoRoute(
      path: '/admin',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
  ],
);
