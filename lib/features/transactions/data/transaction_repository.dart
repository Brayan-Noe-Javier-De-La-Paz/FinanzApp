import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '/config/network_service.dart'; // Ajusta la ruta si es necesario
import '/core/local_database.dart'; // Ajusta la ruta si es necesario
import '/core/sync_service.dart'; // Asegúrate de que esto esté arriba
import 'package:flutter/foundation.dart' show kIsWeb;
class TransactionRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ==========================================
  // 🛡️ SECCIÓN 1: LECTURAS HÍBRIDAS (READ)
  // Intenta leer de Supabase. Si falla o no hay internet, lee de SQLite.
  // ==========================================

  Future<List<Map<String, dynamic>>> getCategorias() async {
    try {
      if (await NetworkService().hasInternet()) {
        final res = await _client
            .from('categorias')
            .select('id, nombre, tipo, codigo_icono, color_hex')
            .order('nombre');
        return List<Map<String, dynamic>>.from(res);
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      // 📱 PLAN B: SQLite
      if (kIsWeb) return []; // Si estamos en la web y falla Supabase, no hay SQLite para leer, así que devolvemos vacío
      final db = await LocalDatabase.instance.database;
      return await db.query('categorias', orderBy: 'nombre');
    }
  }

  Future<List<Map<String, dynamic>>> getCuentas() async {
    try {
      if (await NetworkService().hasInternet()) {
        final userId = _client.auth.currentUser!.id;
        final res = await _client
            .from('cuentas')
            .select('id, nombre, saldo, es_credito')
            .eq('id_usuario', userId)
            .order('nombre');
        return List<Map<String, dynamic>>.from(res);
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      // 📱 PLAN B: SQLite (Traduciendo el 1 y 0 a true y false)
      if (kIsWeb) return []; // Si estamos en la web y falla Supabase, no hay SQLite para leer, así que devolvemos vacío
      final db = await LocalDatabase.instance.database;
      final locales = await db.query('cuentas', orderBy: 'nombre');
      return locales
          .map((c) => {
                'id': c['id'],
                'nombre': c['nombre'],
                'saldo': c['saldo'],
                'es_credito': c['es_credito'] == 1,
              })
          .toList();
    }
  }

  Future<double> obtenerBalanceTotal() async {
    try {
      if (await NetworkService().hasInternet()) {
        final userId = _client.auth.currentUser!.id;
        final res = await _client
            .from('transacciones')
            .select('monto, tipo')
            .eq('id_usuario', userId);
        double balance = 0.0;
        for (var t in res) {
          final m = (t['monto'] as num).toDouble();
          if (t['tipo'] == 'INGRESO')
            balance += m;
          else
            balance -= m;
        }
        return balance;
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      // 📱 PLAN B: SQLite
      if (kIsWeb) return 0.0;
      final db = await LocalDatabase.instance.database;
      final locales =
          await db.query('transacciones', columns: ['monto', 'tipo']);
      double balance = 0.0;
      for (var t in locales) {
        final m = (t['monto'] as num).toDouble();
        if (t['tipo'] == 'INGRESO')
          balance += m;
        else
          balance -= m;
      }
      return balance;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerUltimosMovimientos() async {
    try {
      if (await NetworkService().hasInternet()) {
        final userId = _client.auth.currentUser!.id;
        final res = await _client
            .from('transacciones')
            .select(
                '*, categorias(nombre, codigo_icono, color_hex), cuentas(nombre)')
            .eq('id_usuario', userId)
            .order('fecha_transaccion', ascending: false)
            .limit(5);
        return List<Map<String, dynamic>>.from(res);
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      // 📱 PLAN B: SQLite (Con JOIN para emular a Supabase)
      if (kIsWeb) return [];
      final db = await LocalDatabase.instance.database;
      final result = await db.rawQuery('''
        SELECT t.*, c.nombre as cat_nombre, c.codigo_icono as cat_icono, c.color_hex as cat_color, cu.nombre as cu_nombre
        FROM transacciones t LEFT JOIN categorias c ON t.id_categoria = c.id LEFT JOIN cuentas cu ON t.id_cuenta = cu.id
        ORDER BY t.fecha DESC LIMIT 5
      ''');
      return result
          .map((r) => {
                'id': r['id'],
                'monto': r['monto'],
                'tipo': r['tipo'],
                'descripcion': r['descripcion'],
                'fecha_transaccion': r['fecha'],
                'categorias': {
                  'nombre': r['cat_nombre'] ?? 'Sin categoría',
                  'codigo_icono': r['cat_icono'],
                  'color_hex': r['cat_color'] ?? '#808080'
                },
                'cuentas': {'nombre': r['cu_nombre'] ?? 'Sin cuenta'}
              })
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialCompleto() async {
    try {
      if (await NetworkService().hasInternet()) {
        final userId = _client.auth.currentUser!.id;
        final res = await _client
            .from('transacciones')
            .select(
                '*, categorias(nombre, codigo_icono, color_hex), cuentas(nombre)')
            .eq('id_usuario', userId)
            .order('fecha_transaccion', ascending: false)
            .limit(100);
        return List<Map<String, dynamic>>.from(res);
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      // 📱 PLAN B: SQLite
      if (kIsWeb) return [];
      final db = await LocalDatabase.instance.database;
      final result = await db.rawQuery('''
        SELECT t.*, c.nombre as cat_nombre, c.codigo_icono as cat_icono, c.color_hex as cat_color, cu.nombre as cu_nombre
        FROM transacciones t LEFT JOIN categorias c ON t.id_categoria = c.id LEFT JOIN cuentas cu ON t.id_cuenta = cu.id
        ORDER BY t.fecha DESC LIMIT 100
      ''');
      return result
          .map((r) => {
                'id': r['id'],
                'monto': r['monto'],
                'tipo': r['tipo'],
                'descripcion': r['descripcion'],
                'fecha_transaccion': r['fecha'],
                'categorias': {
                  'nombre': r['cat_nombre'] ?? 'Sin categoría',
                  'codigo_icono': r['cat_icono'],
                  'color_hex': r['cat_color'] ?? '#808080'
                },
                'cuentas': {'nombre': r['cu_nombre'] ?? 'Sin cuenta'}
              })
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> obtenerSaldosPorCuenta() async {
    final cuentas = await getCuentas();
    List<Map<String, dynamic>> transacciones = [];
    try {
      if (await NetworkService().hasInternet()) {
        final userId = _client.auth.currentUser!.id;
        final res = await _client
            .from('transacciones')
            .select('monto, tipo, id_cuenta')
            .eq('id_usuario', userId);
        transacciones = List<Map<String, dynamic>>.from(res);
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      // 📱 PLAN B: SQLite
      if (kIsWeb) return [];
      final db = await LocalDatabase.instance.database;
      transacciones = await db
          .query('transacciones', columns: ['monto', 'tipo', 'id_cuenta']);
    }

    List<Map<String, dynamic>> calculadas = [];
    for (var c in cuentas) {
      double saldo = (c['saldo'] as num).toDouble();
      final movs = transacciones.where((t) => t['id_cuenta'] == c['id']);
      for (var m in movs) {
        final monto = (m['monto'] as num).toDouble();
        if (m['tipo'] == 'INGRESO')
          saldo += monto;
        else
          saldo -= monto;
      }
      calculadas.add({
        'id': c['id'],
        'nombre': c['nombre'],
        'saldo_actual': saldo,
        'es_credito': c['es_credito']
      });
    }
    return calculadas;
  }

// 📊 GRÁFICA 1: Gastos del mes actual (Pantalla Principal)
  Future<List<Map<String, dynamic>>> obtenerGastosPorCategoria() async {
    final now = DateTime.now();
    List<Map<String, dynamic>> datos = [];

    try {
      if (await NetworkService().hasInternet()) {
        final inicioMes = DateTime(now.year, now.month, 1).toIso8601String();
        final finMes =
            DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();
        final userId = _client.auth.currentUser!.id;
        final res = await _client
            .from('transacciones')
            .select('monto, categorias(nombre, color_hex)')
            .eq('id_usuario', userId)
            .eq('tipo', 'GASTO')
            .gte('fecha_transaccion', inicioMes)
            .lte('fecha_transaccion', finMes);
        datos = List<Map<String, dynamic>>.from(res);
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      // 📱 PLAN B (Filtro 100% en Dart, a prueba de fallos de Zonas Horarias)
      if (kIsWeb) return [];
      final db = await LocalDatabase.instance.database;
      final locales = await db.rawQuery('''
        SELECT t.monto, t.fecha, c.nombre as cat_nombre, c.color_hex as cat_color
        FROM transacciones t LEFT JOIN categorias c ON t.id_categoria = c.id
        WHERE t.tipo = 'GASTO'
      ''');

      datos = locales
          .where((r) {
            if (r['fecha'] == null) return false;
            // Convertimos el texto a una Fecha real y a tu hora local
            final fechaTx = DateTime.parse(r['fecha'].toString()).toLocal();
            return fechaTx.year == now.year && fechaTx.month == now.month;
          })
          .map((r) => {
                'monto': r['monto'],
                'categorias': {
                  'nombre': r['cat_nombre'],
                  'color_hex': r['cat_color']
                }
              })
          .toList();
    }

    Map<String, Map<String, dynamic>> agrupado = {};
    for (var t in datos) {
      final nombreCat = t['categorias']?['nombre'] ?? 'Otros';
      final colorHex = t['categorias']?['color_hex'] ?? '#808080';
      final monto = (t['monto'] as num).toDouble();
      if (agrupado.containsKey(nombreCat))
        agrupado[nombreCat]!['total'] += monto;
      else
        agrupado[nombreCat] = {
          'nombre': nombreCat,
          'color': colorHex,
          'total': monto
        };
    }
    final lista = agrupado.values.toList();
    lista
        .sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return lista;
  }

  // 📊 GRÁFICA 2: Gastos por mes específico (Pantalla de Estadísticas)
  Future<List<Map<String, dynamic>>> obtenerGastosPorMes(
      int mes, int anio) async {
    List<Map<String, dynamic>> datos = [];

    try {
      if (await NetworkService().hasInternet()) {
        final inicioMes = DateTime(anio, mes, 1).toIso8601String();
        final finMes = DateTime(anio, mes + 1, 0, 23, 59, 59).toIso8601String();
        final userId = _client.auth.currentUser!.id;
        final res = await _client
            .from('transacciones')
            .select('monto, categorias(nombre, color_hex, codigo_icono)')
            .eq('id_usuario', userId)
            .eq('tipo', 'GASTO')
            .gte('fecha_transaccion', inicioMes)
            .lte('fecha_transaccion', finMes);
        datos = List<Map<String, dynamic>>.from(res);
      } else {
        throw Exception("Offline");
      }
    } catch (e) {
      // 📱 PLAN B (Filtro en Dart con "Micrófonos")
      if (kIsWeb) return [];
      print("📱 [OFFLINE] Buscando gastos para el mes $mes del $anio...");
      final db = await LocalDatabase.instance.database;

      final locales = await db.rawQuery('''
        SELECT t.monto, t.fecha, c.nombre as cat_nombre, c.color_hex as cat_color, c.codigo_icono as cat_icono
        FROM transacciones t LEFT JOIN categorias c ON t.id_categoria = c.id
        WHERE t.tipo = 'GASTO'
      ''');

      print(
          "📱 [OFFLINE] Se encontraron ${locales.length} gastos TOTALES en SQLite.");

      datos = locales
          .where((r) {
            if (r['fecha'] == null) return false;
            try {
              // Extraemos el año y mes directamente del texto para evitar errores de zona horaria
              final fechaTexto = r['fecha'].toString();
              final anioTx = int.parse(fechaTexto.substring(0, 4));
              final mesTx = int.parse(fechaTexto.substring(5, 7));

              return anioTx == anio && mesTx == mes;
            } catch (e) {
              print("⚠️ Error leyendo fecha: ${r['fecha']}");
              return false;
            }
          })
          .map((r) => {
                'monto': r['monto'],
                'categorias': {
                  'nombre': r['cat_nombre'],
                  'color_hex': r['cat_color'],
                  'codigo_icono': r['cat_icono']
                }
              })
          .toList();

      print(
          "📱 [OFFLINE] Después de filtrar por el mes $mes, quedaron: ${datos.length} gastos.");
    }

    Map<String, double> agrupado = {};
    Map<String, Map<String, dynamic>> infoCategoria = {};
    double totalMes = 0;

    for (var t in datos) {
      final cat = t['categorias'];
      if (cat == null) continue;

      // 🔥 SALVAVIDAS: Si el nombre es null, lo forzamos a ser String 'Otros'
      final String nombre = (cat['nombre'] ?? 'Otros').toString();
      final monto = (t['monto'] as num).toDouble();

      totalMes += monto;

      if (agrupado.containsKey(nombre)) {
        agrupado[nombre] = agrupado[nombre]! + monto;
      } else {
        agrupado[nombre] = monto;
        // 🔥 SALVAVIDAS 2: Protegemos colores e íconos nulos
        infoCategoria[nombre] = {
          'color': cat['color_hex'] ?? '#808080',
          'icono': cat['codigo_icono'] ?? ''
        };
      }
    }

    // Convertimos al resultado final (Esto se queda igual)
    List<Map<String, dynamic>> resultado = [];
    agrupado.forEach((nombre, montoTotal) {
      final info = infoCategoria[nombre]!;
      final porcentaje = (totalMes == 0) ? 0.0 : (montoTotal / totalMes) * 100;
      resultado.add({
        'categoria': nombre,
        'monto': montoTotal,
        'porcentaje': porcentaje,
        'color_hex': info['color'],
        'icono_code': info['icono']
      });
    });
    resultado.sort((a, b) => b['monto'].compareTo(a['monto']));
    return resultado;
  }

  // ==========================================
  // 🚀 SECCIÓN 2: ESCRITURAS HÍBRIDAS (CUD)
  // Si hay internet suben a Supabase. Si no, se van a la cola local.
  // ==========================================

  Future<void> crearCategoria(
      {required String nombre,
      required String tipo,
      required String codigoIcono,
      required String colorHex}) async {
    final payload = {
      'id_usuario': _client.auth.currentUser!.id,
      'nombre': nombre,
      'tipo': tipo,
      'codigo_icono': codigoIcono,
      'color_hex': colorHex,
    };
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('categorias').insert(payload);
      } catch (e) {
        await _guardarOperacionLocal('categorias', 'INSERT', payload);
      }
    } else {
      await _guardarOperacionLocal('categorias', 'INSERT', payload);
    }
  }

  Future<void> editarCategoria(
      {required String id,
      required String nombre,
      required String codigoIcono,
      required String colorHex}) async {
    final payload = {
      'id': id,
      'nombre': nombre,
      'codigo_icono': codigoIcono,
      'color_hex': colorHex
    };
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('categorias').update(payload).eq('id', id);
      } catch (e) {
        await _guardarOperacionLocal('categorias', 'UPDATE', payload);
      }
    } else {
      await _guardarOperacionLocal('categorias', 'UPDATE', payload);
    }
  }

  Future<void> crearCuenta(
      {required String nombre,
      required double saldoInicial,
      required bool esCredito}) async {
    final payload = {
      'id_usuario': _client.auth.currentUser!.id,
      'nombre': nombre, 'saldo': 0.0, 'es_credito': esCredito, // Nace en 0
    };

    if (await NetworkService().hasInternet()) {
      try {
        final cuentaResponse =
            await _client.from('cuentas').insert(payload).select().single();
        if (saldoInicial > 0 && !esCredito) {
          // (Lógica de saldo inicial simplificada para asegurar guardado)
          await crearTransaccion(
              accountId: cuentaResponse['id'],
              amount: saldoInicial,
              type: 'INGRESO',
              description: 'Saldo Inicial',
              date: DateTime.now());
        }
      } catch (e) {
        await _guardarOperacionLocal(
            'cuentas', 'INSERT', payload); // Guardar cuenta en cola
      }
    } else {
      await _guardarOperacionLocal('cuentas', 'INSERT',
          payload); // Pendiente: Manejar el saldo inicial offline
    }
  }

  Future<void> editarCuenta(
      {required String id,
      required String nombre,
      required double saldoInicial,
      required bool esCredito}) async {
    final payload = {
      'id': id,
      'nombre': nombre,
      'saldo': saldoInicial,
      'es_credito': esCredito
    };
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('cuentas').update(payload).eq('id', id);
      } catch (e) {
        await _guardarOperacionLocal('cuentas', 'UPDATE', payload);
      }
    } else {
      await _guardarOperacionLocal('cuentas', 'UPDATE', payload);
    }
  }

  Future<void> eliminarCuenta(String id) async {
    final payload = {'id': id};
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('transacciones').delete().eq('id_cuenta', id);
        await _client.from('cuentas').delete().eq('id', id);
      } catch (e) {
        await _guardarOperacionLocal('cuentas', 'DELETE', payload);
      }
    } else {
      await _guardarOperacionLocal('cuentas', 'DELETE', payload);
    }
  }

  Future<void> crearTransaccion(
      {required String accountId,
      String? categoryId,
      required double amount,
      required String type,
      required String description,
      required DateTime date}) async {
    final payload = {
      'id_usuario': _client.auth.currentUser!.id,
      'id_cuenta': accountId,
      'id_categoria': categoryId,
      'monto': amount,
      'tipo': type,
      'descripcion': description,
      'fecha_transaccion': date.toIso8601String(),
    };

    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('transacciones').insert(payload);
        SyncService.instance
            .sincronizarTodo(); // Refresca el espejo local rápido
      } catch (e) {
        await _guardarOperacionLocal('transacciones', 'INSERT', payload);
        await _agregarAlEspejoLocal(payload); // ⚡ Actualización Optimista
      }
    } else {
      await _guardarOperacionLocal('transacciones', 'INSERT', payload);
      await _agregarAlEspejoLocal(payload); // ⚡ Actualización Optimista
    }
  }

  Future<void> editarTransaccion(
      {required String id,
      required String accountId,
      required String categoryId,
      required double amount,
      required String type,
      required String description,
      required DateTime date}) async {
    final payload = {
      'id': id,
      'id_usuario': _client.auth.currentUser!.id,
      'id_cuenta': accountId,
      'id_categoria': categoryId,
      'monto': amount,
      'tipo': type,
      'descripcion': description,
      'fecha_transaccion': date.toIso8601String(),
    };
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('transacciones').update(payload).eq('id', id);
      } catch (e) {
        await _guardarOperacionLocal('transacciones', 'UPDATE', payload);
      }
    } else {
      await _guardarOperacionLocal('transacciones', 'UPDATE', payload);
    }
  }

  Future<void> eliminarTransaccion(String id) async {
    final payload = {'id': id};
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('transacciones').delete().eq('id', id);
      } catch (e) {
        await _guardarOperacionLocal('transacciones', 'DELETE', payload);
      }
    } else {
      await _guardarOperacionLocal('transacciones', 'DELETE', payload);
    }
  }
// ⏰ CREAR RECORDATORIO (Escritura Híbrida)
  Future<void> crearRecordatorio({required String titulo, required DateTime fechaHora}) async {
    final payload = {
      'id_usuario': _client.auth.currentUser!.id,
      'titulo': titulo,
      'fecha_hora': fechaHora.toIso8601String(),
      'completado': false,
    };

    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('recordatorios').insert(payload);
        SyncService.instance.sincronizarTodo(); // Actualiza el espejo
      } catch (e) {
        await _guardarOperacionLocal('recordatorios', 'INSERT', payload);
      }
    } else {
      await _guardarOperacionLocal('recordatorios', 'INSERT', payload);
    }
  }

  // ⏰ ACTUALIZAR ESTADO DE RECORDATORIO
  Future<void> actualizarEstadoRecordatorio(String id, bool completado) async {
    final payload = {'id': id, 'completado': completado};
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('recordatorios').update(payload).eq('id', id);
      } catch (e) {
        await _guardarOperacionLocal('recordatorios', 'UPDATE', payload);
      }
    } else {
      await _guardarOperacionLocal('recordatorios', 'UPDATE', payload);
    }
  }

  // ⏰ ELIMINAR RECORDATORIO
  Future<void> eliminarRecordatorio(String id) async {
    final payload = {'id': id};
    if (await NetworkService().hasInternet()) {
      try {
        await _client.from('recordatorios').delete().eq('id', id);
      } catch (e) {
        await _guardarOperacionLocal('recordatorios', 'DELETE', payload);
      }
    } else {
      await _guardarOperacionLocal('recordatorios', 'DELETE', payload);
    }
  }
  // ==========================================
  // ⚙️ SECCIÓN 3: EL MOTOR LOCAL (HELPER)
  // Empaqueta los datos y los guarda en SQLite
  // ==========================================

  Future<void> _guardarOperacionLocal(String tabla, String accion, Map<String, dynamic> payload) async {
    if (kIsWeb) return; // 🛡️ ESCUDO WEB: No intentamos usar SQLite en la web, simplemente no guardamos la operación (podrías mejorar esto mostrando un mensaje al usuario)
    final db = await LocalDatabase.instance.database;
    await db.insert('operaciones_pendientes', {
      'tabla_destino': tabla,
      'accion': accion,
      'datos_json': jsonEncode(payload),
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
    print("💾 📡 ¡MODO OFFLINE! Guardado en cola: $accion en $tabla.");
  }

  // ⚡ FUNCIÓN AUXILIAR: Añade el registro al Espejo Local al instante
  Future<void> _agregarAlEspejoLocal(Map<String, dynamic> payload) async {
    if (kIsWeb) return;
    final db = await LocalDatabase.instance.database;
    await db.insert('transacciones', {
      'id':
          'temp_${DateTime.now().millisecondsSinceEpoch}', // ID fantasma temporal
      'monto': payload['monto'],
      'descripcion': payload['descripcion'],
      'tipo': payload['tipo'],
      'fecha': payload['fecha_transaccion'],
      'id_categoria': payload['id_categoria'],
      'id_cuenta': payload['id_cuenta'],
    });
  }
}
