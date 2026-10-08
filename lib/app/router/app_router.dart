import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/community/presentation/pages/community_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/trips/presentation/pages/trip_detail_page.dart';
import '../../features/trips/presentation/pages/trip_form_page.dart';
import '../../features/trips/presentation/pages/trips_page.dart';
import '../../features/vehicle/presentation/pages/vehicle_form_page.dart';
import '../../features/vehicle/presentation/pages/vehicles_page.dart';
import '../shell/main_shell.dart';

GoRouter createAppRouter({
  required bool Function() isAuthenticated,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final loggedIn = isAuthenticated();

      final onLogin = state.matchedLocation == '/login';

      final onRegister = state.matchedLocation == '/register';

      final onAuthPage = onLogin || onRegister;

      if (!loggedIn && !onAuthPage) {
        return '/login';
      }

      if (loggedIn && onAuthPage) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          return const LoginPage();
        },
      ),

      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) {
          return const RegisterPage();
        },
      ),

      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return MainShell(navigationShell: navigationShell);
            },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) {
                  return const HomePage();
                },
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                name: 'trips',
                builder: (context, state) {
                  return const TripsPage();
                },
                routes: [
                  GoRoute(
                    path: 'create',
                    name: 'trip-create',
                    builder: (context, state) {
                      return const TripFormPage();
                    },
                  ),

                  GoRoute(
                    path: ':tripId',
                    name: 'trip-detail',
                    builder: (context, state) {
                      final tripId = state.pathParameters['tripId']!;

                      return TripDetailPage(tripId: tripId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'trip-edit',
                        builder: (context, state) {
                          final tripId = state.pathParameters['tripId']!;

                          return TripFormPage(tripId: tripId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                name: 'map',
                builder: (context, state) {
                  return const MapPage();
                },
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                name: 'community',
                builder: (context, state) {
                  return const CommunityPage();
                },
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) {
                  return const ProfilePage();
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'edit-profile',
                    builder: (context, state) {
                      return const EditProfilePage();
                    },
                  ),

                  GoRoute(
                    path: 'vehicles',
                    name: 'vehicles',
                    builder: (context, state) {
                      return const VehiclesPage();
                    },
                    routes: [
                      GoRoute(
                        path: 'add',
                        name: 'vehicle-add',
                        builder: (context, state) {
                          return const VehicleFormPage();
                        },
                      ),

                      GoRoute(
                        path: ':vehicleId/edit',
                        name: 'vehicle-edit',
                        builder: (context, state) {
                          final vehicleId = state.pathParameters['vehicleId']!;

                          return VehicleFormPage(vehicleId: vehicleId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
