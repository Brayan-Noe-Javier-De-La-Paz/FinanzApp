import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/local_database.dart'; // Ajusta la ruta a tu archivo
import '../config/network_service.dart'; // Ajusta la ruta a tu archivo
import 'package:flutter/foundation.dart' show kIsWeb;
class SyncService {
  // Patrón Singleton para usar la misma instancia en toda la app
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final _supabase = Supabase.instance.client;

  // 🚀 FUNCIÓN PRINCIPAL: El botón de "Play" del motor
  Future<void> sincronizarTodo() async {
    // Si no hay internet o el usuario no ha iniciado sesión, abortamos
    if (kIsWeb) {
      print("🌐 Modo Web: Saltando motor SQLite");
      return; 
    }

    if (!await NetworkService().hasInternet()) return;
    if (_supabase.auth.currentUser == null) return;


    try {
      print("🔄 Iniciando sincronización de FinanzApp...");
      await _subirPendientesALaNube();
      await _descargarDesdeLaNube();
      print("✅ Sincronización completada con éxito.");
    } catch (e) {
      print("⚠️ Error crítico en la sincronización: $e");
    }
  }

  // ⬆️ FASE 1: DESATASCAR LA COLA (Subir lo que hiciste offline)
  Future<void> _subirPendientesALaNube() async {
    final db = await LocalDatabase.instance.database;
    final pendientes = await db.query('operaciones_pendientes', orderBy: 'id ASC');

    if (pendientes.isEmpty) {
      print("☁️ No hay operaciones pendientes por subir.");
      return;
    }

    print("⬆️ Subiendo ${pendientes.length} operaciones a Supabase...");

    for (var op in pendientes) {
      try {
        final idOp = op['id'] as int;
        final tabla = op['tabla_destino'] as String;
        final accion = op['accion'] as String;
        final payload = jsonDecode(op['datos_json'] as String);

        // Ejecutamos la acción según lo que el usuario hizo offline
        if (accion == 'INSERT') {
          await _supabase.from(tabla).insert(payload);
        } else if (accion == 'UPDATE') {
          await _supabase.from(tabla).update(payload).eq('id', payload['id']);
        } else if (accion == 'DELETE') {
          await _supabase.from(tabla).delete().eq('id', payload['id']);
        }

        // Si la subida fue exitosa, borramos esta operación de la cola local
        await db.delete('operaciones_pendientes', where: 'id = ?', whereArgs: [idOp]);
        
      } catch (e) {
        print("❌ Error subiendo operación ${op['id']} a $op['tabla_destino']: $e");
        // Si falla, se queda en la cola de SQLite para intentar de nuevo más tarde
      }
    }
  }

  // ⬇️ FASE 2: CLONAR LA NUBE AL TELÉFONO (El Espejo)
  Future<void> _descargarDesdeLaNube() async {
    final userId = _supabase.auth.currentUser!.id;
    final db = await LocalDatabase.instance.database;

    print("⬇️ Descargando copia de seguridad de la nube...");

    // 1. Descargamos todo de Supabase
    final cuentas = await _supabase.from('cuentas').select().eq('id_usuario', userId);
    final transacciones = await _supabase.from('transacciones').select().eq('id_usuario', userId);
    final categorias = await _supabase.from('categorias').select(); 
    final recordatorios = await _supabase.from('recordatorios').select().eq('id_usuario', userId);

    // 2. Usamos una "Transacción" para limpiar y llenar rapidísimo
    await db.transaction((txn) async {
      
      // A. Borramos los datos viejos del celular
      await txn.delete('cuentas');
      await txn.delete('transacciones');
      await txn.delete('categorias');
      await txn.delete('recordatorios');

      // B. Filtramos y guardamos CUENTAS (Convirtiendo el bool a 0/1)
      for (var c in cuentas) {
        await txn.insert('cuentas', {
          'id': c['id'].toString(),
          'nombre': c['nombre'],
          'saldo': c['saldo'],
          'es_credito': c['es_credito'] == true ? 1 : 0, 
        });
      }

      // C. Filtramos y guardamos TRANSACCIONES (Mapeando nombres correctos)
      for (var t in transacciones) {
        await txn.insert('transacciones', {
          'id': t['id'].toString(),
          'monto': t['monto'],
          'descripcion': t['descripcion'],
          'tipo': t['tipo'],
          'fecha': t['fecha_transaccion'], // En Supabase es fecha_transaccion, en local es fecha
          'id_categoria': t['id_categoria']?.toString(), // Puede ser null
          'id_cuenta': t['id_cuenta']?.toString(), // Puede ser null
        });
      }

      // D. Filtramos y guardamos CATEGORÍAS
      for (var cat in categorias) {
        await txn.insert('categorias', {
          'id': cat['id'].toString(),
          'nombre': cat['nombre'],
          'tipo': cat['tipo'],
          'codigo_icono': cat['codigo_icono'],
          'color_hex': cat['color_hex'],
        });
      }

      // 3. Traducimos y guardamos los recordatorios locales

      for (var rec in recordatorios) {
        await txn.insert('recordatorios', {
          'id': rec['id'].toString(),
          'titulo': rec['titulo'],
          'monto': rec['monto'],
          'fecha_limite': rec['fecha_limite'], // 👈 Nombre real
          'esta_pagado': rec['esta_pagado'] == true ? 1 : 0, // 👈 Nombre real
        });
      }
    });
    
    print("📱 Base de datos local actualizada. ¡Espejo 100% sincronizado!");
  }
}