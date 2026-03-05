
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/dashboard/presentation/accounts_screen.dart';
import '../features/dashboard/presentation/add_account_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/transactions/presentation/add_transaction_screen.dart';
import '../features/chat_ai/presentation/chat_screen.dart';
import '../features/dashboard/presentation/statistics_screen.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/transactions/presentation/history_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/categories/presentation/manage_categories_screen.dart';
import '../features/profile/preferences_screen.dart';
import '../features/profile/seguridad_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  // Esta función revisa si el usuario tiene sesión cada vez que intenta navegar
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    // Si no hay sesión y no está en login/registro, mándalo al login
    if (session == null && !isLoggingIn) return '/login';

    // Si YA hay sesión y trata de ir al login, mándalo al home
    if (session != null && isLoggingIn) return '/home';

    return null; // Si todo está bien, déjalo pasar
  },
  routes: [
    // RUTA 1: Login
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // RUTA 2: Registro
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    // RUTA 3: Home (Dashboard)
GoRoute(
  path: '/home',
  builder: (context, state) => const HomeScreen(), 
),
GoRoute(
      path: '/add-transaction',
      builder: (context, state) {
        final extra = state.extra;
        
        // Preparamos el mapa de parámetros 'params'
        Map<String, dynamic> params = {};

        if (extra is String) {
          // Caso 1: Viene solo un texto (Ej: "GASTO")
          params = {'tipo': extra};
        } else if (extra is Map) {
          // Caso 2: Viene un mapa (Edición o Configuración compleja como Abono)
          params = Map<String, dynamic>.from(extra);
        }

        // Enviamos todo en el nuevo argumento 'params'
        return AddTransactionScreen(
          params: params, 
        );
      },
    
    ),
GoRoute(
  path: '/chat',
  builder: (context, state) => const ChatScreen(),
),
GoRoute(
  path: '/stats',
  builder: (context, state) => const StatisticsScreen(),
),
GoRoute(
  path: '/reminders',
  builder: (context, state) => const RemindersScreen(),
),
GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(path: '/accounts', builder: (context, state) => const AccountsScreen()),
    // Busca esta ruta y REEMPLÁZALA:
    GoRoute(
      path: '/add-account',
      builder: (context, state) {
        // Recibimos el objeto cuenta si queremos editar
        final cuenta = state.extra as Map<String, dynamic>?;
        return AddAccountScreen(cuentaEditar: cuenta);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/manage-categories',
      builder: (context, state) => const ManageCategoriesScreen(),
    ),
    GoRoute(
      path: '/preferences',
      builder: (context, state) => const PreferencesScreen(),
    ),
    GoRoute(
  path: '/seguridad',
  builder: (context, state) => const SeguridadScreen(),
),
  ],
  
);