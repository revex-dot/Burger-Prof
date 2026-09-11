import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screens.dart';
import '../../features/auth/lock_screen.dart';
import '../../features/community/community_screens.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/donations/giving_screens.dart';
import '../../features/experts/expert_screens.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/learn/learn_screens.dart';
import '../../features/marketplace/marketplace_screens.dart';
import '../../features/premium/premium_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/training/training_screens.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import 'app_shell.dart';

class Routes {
  static const login = '/login';
  static const signup = '/signup';
  static const lock = '/lock';
  static const home = '/home';
  static const learn = '/learn';
  static const train = '/train';
  static const community = '/community';
  static const give = '/give';
  static const gallery = '/gallery';
  static const reminders = '/reminders';
  static const experts = '/experts';
  static const consultations = '/consultations';
  static const premium = '/premium';
  static const shop = '/shop';
  static const cart = '/shop/cart';
  static const settings = '/settings';
  static const newPost = '/community/new';
  static const logSession = '/train/log';
  static const addGoal = '/train/goal/new';

  static String guide(String id) => '/learn/$id';
  static String goal(String id) => '/train/goal/$id';
  static String post(String id) => '/community/post/$id';
  static String donate(String charityId) => '/give/donate/$charityId';
  static String expert(String id) => '/experts/$id';
  static String consultation(String id) => '/consultations/$id';
}

/// Rebuilds GoRouter's redirect when auth / lock state changes.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this.ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(biometricLockEnabledProvider, (_, __) => notifyListeners());
    ref.listen(appUnlockedProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.valueOrNull != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == Routes.login || loc == Routes.signup;

      if (!signedIn) return onAuthPage ? null : Routes.login;
      if (onAuthPage) return Routes.home;

      final lockEnabled = ref.read(biometricLockEnabledProvider);
      final unlocked = ref.read(appUnlockedProvider);
      if (lockEnabled && !unlocked && loc != Routes.lock) return Routes.lock;
      if ((!lockEnabled || unlocked) && loc == Routes.lock) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (_, __) => const SignUpScreen()),
      GoRoute(path: Routes.lock, builder: (_, __) => const LockScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, __) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.learn,
              builder: (_, __) => const LearnScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) =>
                      GuideDetailScreen(guideId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.train,
              builder: (_, __) => const TrainingScreen(),
              routes: [
                GoRoute(
                  path: 'log',
                  builder: (_, s) => LogSessionScreen(
                    goalId: s.uri.queryParameters['goalId'],
                  ),
                ),
                GoRoute(
                  path: 'goal/new',
                  builder: (_, s) => AddGoalScreen(
                    guideId: s.uri.queryParameters['guideId'],
                  ),
                ),
                GoRoute(
                  path: 'goal/:id',
                  builder: (_, s) =>
                      GoalDetailScreen(goalId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.community,
              builder: (_, __) => const CommunityScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, __) => const NewPostScreen(),
                ),
                GoRoute(
                  path: 'post/:id',
                  builder: (_, s) =>
                      PostDetailScreen(postId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.give,
              builder: (_, __) => const GivingScreen(),
              routes: [
                GoRoute(
                  path: 'donate/:charityId',
                  builder: (_, s) => DonateScreen(
                    charityId: s.pathParameters['charityId']!,
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(path: Routes.gallery, builder: (_, __) => const GalleryScreen()),
      GoRoute(
        path: Routes.reminders,
        builder: (_, __) => const RemindersScreen(),
      ),
      GoRoute(
        path: Routes.experts,
        builder: (_, __) => const ExpertsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) =>
                ExpertDetailScreen(expertId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.consultations,
        builder: (_, __) => const ConsultationsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) =>
                ConsultationChatScreen(consultationId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: Routes.premium, builder: (_, __) => const PremiumScreen()),
      GoRoute(
        path: Routes.shop,
        builder: (_, __) => const MarketplaceScreen(),
        routes: [
          GoRoute(path: 'cart', builder: (_, __) => const CartScreen()),
        ],
      ),
      GoRoute(
          path: Routes.settings, builder: (_, __) => const SettingsScreen()),
    ],
  );
});
