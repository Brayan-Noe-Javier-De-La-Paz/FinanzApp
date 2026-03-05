import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'config/notification_service.dart';
import 'firebase_options.dart'; 

// 1. 📢 EL MEGÁFONO GLOBAL (Variable global para escuchar el tema en toda la app)
final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Carga las variables de entorno


  // 🗄️ 1. INICIALIZAR SUPABASE (Para Web y Móviles)
final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  // 🎨 2. LEER PREFERENCIA DE COLOR AL ABRIR LA APP
  if (user != null) {
    // Si hay usuario, leemos cómo dejó el interruptor la última vez
    final temaGuardado = user.userMetadata?['theme'];
    if (temaGuardado == 'dark') {
      appThemeNotifier.value = ThemeMode.dark;
    } else if (temaGuardado == 'light') {
      appThemeNotifier.value = ThemeMode.light;
    }
  }

  // 🔥 3. INICIALIZAR FIREBASE Y NOTIFICACIONES (SOLO MÓVIL)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // 🔔 PEDIR PERMISOS Y OBTENER EL TOKEN VIP
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      
      String? token = await messaging.getToken();  
      print("Token FCM: $token");

      // 💾 GUARDAR TOKEN EN SUPABASE
      if (token != null && user != null) {
        try {
          await supabase.from('perfiles').update({'fcm_token': token}).eq('id', user.id);
          print("✅ Token guardado en Supabase");
        } catch (e) {
          print("⚠️ Error guardando el token: $e");
        }
      }
    } catch (e) {
      print("Error con FCM: $e");
    }
  } else {
    print("🌐 Modo Web detectado: Saltando Notificaciones Push y Token");
  }

  // 📅 4. INICIALIZAR FORMATO DE FECHAS
  await initializeDateFormatting('es_MX', null);
  tz.initializeTimeZones();

  // 🔔 5. INICIALIZAR NOTIFICACIONES LOCALES (Protegido para Web)
  if (!kIsWeb) {
    try {
      await NotificationService().init();
    } catch (e) {
      print("⚠️ Error con Notificaciones Locales: $e");
    }
  }

  // 🚀 6. ARRANCAR LA APP
  runApp(const FinanzApp());
}

class FinanzApp extends StatelessWidget {
  const FinanzApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🎧 ESCUCHAR EL MEGÁFONO
    // ValueListenableBuilder redibuja TODA la app cuando el notifier cambia
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp.router(
          routerConfig: appRouter,
          title: 'FinanzApp',
          debugShowCheckedModeBanner: false,
          
          // --- VISUAL ---
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode, // <-- ¡LA MAGIA SUCEDE AQUÍ!

          // --- IDIOMA ---
          locale: const Locale('es', 'MX'),
          supportedLocales: const [Locale('es', 'MX')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}