import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../../config/network_service.dart'; 
import '../../../core/local_database.dart'; 
import '../../../core/sync_service.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;
class ReminderRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ⏰ 1. OBTENER RECORDATORIOS PENDIENTES
  Future<List<Map<String, dynamic>>> getRecordatoriosPendientes() async {
    try {
      if (await NetworkService().hasInternet()) {
        final userId = _client.auth.currentUser!.id;
        final res = await _client.from('recordatorios')
            .select()
            .eq('id_usuario', userId)
            .eq('esta_pagado', false) // 👈 CORREGIDO
            .order('fecha_limite'); // 👈 CORREGIDO
        return List<Map<String, dynamic>>.from(res);
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      if (kIsWeb) {
         // Si falla Supabase en la web, devolvemos vacío porque no hay SQLite
         return []; 
      }
      print("📱 [OFFLINE] Leyendo recordatorios de SQLite...");
      final db = await LocalDatabase.instance.database;
      final locales = await db.query(
        'recordatorios', 
        where: 'esta_pagado = ?', // 👈 CORREGIDO
        whereArgs: [0], 
        orderBy: 'fecha_limite' // 👈 CORREGIDO
      );
      
      return locales.map((r) => {
        'id': r['id'],
        'titulo': r['titulo'],
        'monto': r['monto'], 
        'fecha_limite': r['fecha_limite'], 
        'esta_pagado': false, 
      }).toList();
    }
  }

  // ⏰ 2. CREAR RECORDATORIO
  Future<void> crearRecordatorio({required String titulo, required double monto, required DateTime fechaLimite, required bool esRecurrente}) async {
    final payload = {
      'id_usuario': _client.auth.currentUser!.id,
      'titulo': titulo,
      'monto': monto,
      'fecha_limite': fechaLimite.toIso8601String(),
      'es_recurrente': esRecurrente,
      'esta_pagado': false, // 👈 CORREGIDO
    };

    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('recordatorios').insert(payload);
        SyncService.instance.sincronizarTodo(); 
      } catch (e) {
        await _guardarOperacionLocal('recordatorios', 'INSERT', payload);
        await _agregarAlEspejoLocal(payload);
      }
    } else {
      await _guardarOperacionLocal('recordatorios', 'INSERT', payload);
      await _agregarAlEspejoLocal(payload);
    }
  }

  // ⏰ 3. MARCAR COMO PAGADO
  Future<void> marcarComoPagado(String id) async {
    final payload = {'id': id, 'esta_pagado': true}; // 👈 CORREGIDO
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('recordatorios').update(payload).eq('id', id);
        SyncService.instance.sincronizarTodo(); 
      } catch (e) {
        await _guardarOperacionLocal('recordatorios', 'UPDATE', payload);
        await _marcarPagadoLocal(id);
      }
    } else {
      await _guardarOperacionLocal('recordatorios', 'UPDATE', payload);
      await _marcarPagadoLocal(id);
    }
  }

  // ⏰ 4. ELIMINAR RECORDATORIO
  Future<void> eliminarRecordatorio(String id) async {
    final payload = {'id': id};
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('recordatorios').delete().eq('id', id);
        SyncService.instance.sincronizarTodo(); 
      } catch (e) {
        await _guardarOperacionLocal('recordatorios', 'DELETE', payload);
        await _eliminarLocal(id);
      }
    } else {
      await _guardarOperacionLocal('recordatorios', 'DELETE', payload);
      await _eliminarLocal(id);
    }
  }

  // ==========================================
  // ⚙️ HELPERS LOCALES
  // ==========================================

  Future<void> _guardarOperacionLocal(String tabla, String accion, Map<String, dynamic> payload) async {
    if (kIsWeb) return; // No hay SQLite en la web, así que no guardamos nada localmente
    final db = await LocalDatabase.instance.database;
    await db.insert('operaciones_pendientes', {
      'tabla_destino': tabla,
      'accion': accion,
      'datos_json': jsonEncode(payload),
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _agregarAlEspejoLocal(Map<String, dynamic> payload) async {
    if (kIsWeb) return; // 🛡️ ESCUDO WEB
    final db = await LocalDatabase.instance.database;
    await db.insert('recordatorios', {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}', 
      'titulo': payload['titulo'],
      'monto': payload['monto'],
      'fecha_limite': payload['fecha_limite'], // 👈 CORREGIDO
      'esta_pagado': 0, // 👈 CORREGIDO
    });
  }

  Future<void> _marcarPagadoLocal(String id) async {
    if (kIsWeb) return; // 🛡️ ESCUDO WEB
    final db = await LocalDatabase.instance.database;
    await db.update('recordatorios', {'esta_pagado': 1}, where: 'id = ?', whereArgs: [id]); // 👈 CORREGIDO
  }

  Future<void> _eliminarLocal(String id) async {
    if (kIsWeb) return; // 🛡️ ESCUDO WEB
    final db = await LocalDatabase.instance.database;
    await db.delete('recordatorios', where: 'id = ?', whereArgs: [id]);
  }
}