import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/community/presentation/pages/community_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
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

      // Chưa đăng nhập:
      // chỉ cho phép truy cập Login và Register.
      if (!loggedIn && !onAuthPage) {
        return '/login';
      }

      // Đã đăng nhập:
      // không quay lại Login hoặc Register.
      if (loggedIn && onAuthPage) {
        return '/';
      }

      return null;
    },
    routes: [
      // ========================================================
      // AUTH
      // ========================================================

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

      // ========================================================
      // MAIN APPLICATION SHELL
      // ========================================================
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
          // ====================================================
          // 1. HOME
          // ====================================================

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

          // ====================================================
          // 2. TRIPS
          // ====================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                name: 'trips',
                builder: (context, state) {
                  return const TripsPage();
                },
                routes: [
                  // ------------------------------------------------
                  // Create Trip
                  // URL: /trips/create
                  // ------------------------------------------------

                  GoRoute(
                    path: 'create',
                    name: 'trip-create',
                    builder: (context, state) {
                      return const TripFormPage();
                    },
                  ),
                ],
              ),
            ],
          ),

          // ====================================================
          // 3. MAP
          // ====================================================
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

          // ====================================================
          // 4. COMMUNITY
          // ====================================================
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

          // ====================================================
          // 5. PROFILE
          // ====================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) {
                  return const ProfilePage();
                },
                routes: [
                  // ------------------------------------------------
                  // Edit Profile
                  // URL: /profile/edit
                  // ------------------------------------------------

                  GoRoute(
                    path: 'edit',
                    name: 'edit-profile',
                    builder: (context, state) {
                      return const EditProfilePage();
                    },
                  ),

                  // ------------------------------------------------
                  // Vehicles
                  // URL: /profile/vehicles
                  // ------------------------------------------------
                  GoRoute(
                    path: 'vehicles',
                    name: 'vehicles',
                    builder: (context, state) {
                      return const VehiclesPage();
                    },
                    routes: [
                      // --------------------------------------------
                      // Add Vehicle
                      // URL: /profile/vehicles/add
                      // --------------------------------------------

                      GoRoute(
                        path: 'add',
                        name: 'vehicle-add',
                        builder: (context, state) {
                          return const VehicleFormPage();
                        },
                      ),

                      // --------------------------------------------
                      // Edit Vehicle
                      // URL:
                      // /profile/vehicles/{vehicleId}/edit
                      // --------------------------------------------
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
