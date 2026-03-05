import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalDatabase {
  // Patrón Singleton para evitar múltiples conexiones simultáneas
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finanzapp_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Busca la carpeta de documentos interna y segura del celular
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    // Abre la base de datos, si no existe, ejecuta _createDB
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

Future _createDB(Database db, int version) async {
    // 1. TABLA: TRANSACCIONES
    await db.execute('''
      CREATE TABLE transacciones (
        id TEXT PRIMARY KEY,
        monto REAL NOT NULL,
        descripcion TEXT,
        tipo TEXT NOT NULL,
        fecha TEXT NOT NULL,
        id_categoria TEXT,
        id_cuenta TEXT
      )
    ''');

    // 2. TABLA: CUENTAS
    await db.execute('''
      CREATE TABLE cuentas (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        saldo REAL NOT NULL,
        es_credito INTEGER NOT NULL -- SQLite no tiene booleanos, usamos 0 (false) y 1 (true)
      )
    ''');

    // 3. TABLA: CATEGORÍAS
    await db.execute('''
      CREATE TABLE categorias (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        codigo_icono TEXT,
        color_hex TEXT
      )
    ''');

// 4. TABLA: RECORDATORIOS
    await db.execute('''
      CREATE TABLE recordatorios (
        id TEXT PRIMARY KEY,
        titulo TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha_limite TEXT NOT NULL,
        esta_pagado INTEGER DEFAULT 0
      )
    ''');

    // 5. LA COLA MÁGICA: OPERACIONES PENDIENTES
    await db.execute('''
      CREATE TABLE operaciones_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tabla_destino TEXT NOT NULL,
        accion TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
        datos_json TEXT NOT NULL, 
        fecha_creacion TEXT NOT NULL
      )
    ''');
  }

  // Función para cerrar la base de datos si es necesario
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}