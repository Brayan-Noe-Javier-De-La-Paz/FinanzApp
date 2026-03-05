import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// <--- ESTO ES VITAL PARA LA VIBRACIÓN

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    // Configuración Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await notificationsPlugin.initialize(initializationSettings);

    // Configurar Zona Horaria (México)
    try {
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
    } catch (e) {
      print("Error Timezone: $e - Usando Local");
      try {
         tz.setLocalLocation(tz.local);
      } catch (e) {
         print("Error Crítico Timezone: $e");
      }
    }
  }

Future<void> programarRecordatorio({
    required int id,
    required String titulo,
    required DateTime fechaVencimiento,
  }) async {
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'finanzapp_inexact_v105', // Subimos versión para limpiar
      'Recordatorios de Pagos',
      channelDescription: 'Avisos de vencimientos financieros',
      importance: Importance.high, // 'High' es suficiente para modo inexacto
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);
    final tz.TZDateTime fechaProgramada = tz.TZDateTime.from(fechaVencimiento, tz.local);

    // Validación de seguridad
    if (fechaProgramada.isBefore(tz.TZDateTime.now(tz.local))) {
       print("⚠️ Fecha pasada, no se programa.");
       return;
    }

    await notificationsPlugin.zonedSchedule(
      id,
      titulo,
      'Tienes un compromiso de pago pendiente: $titulo',
      fechaProgramada,
      details,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      
      // CAMBIO CLAVE AQUÍ 👇
      // Esto le da permiso a Android de retrasarlo unos minutos si el celular está en reposo profundo.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, 
    );
    
    print("✅ Programado modo Inexacto para: $fechaProgramada");
  }

  Future<void> mostrarNotificacionInmediata({
    required String titulo,
    required String cuerpo,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'finanzapp_test_v100', 
      'Pruebas',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await notificationsPlugin.show(0, titulo, cuerpo, details);
  }

  Future<void> cancelarNotificacion(int id) async {
    await notificationsPlugin.cancel(id);
  }
}