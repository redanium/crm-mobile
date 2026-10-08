import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/doctor.dart';
import '../models/product.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pharma_crm_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Cached Doctors Table
    await db.execute('''
      CREATE TABLE doctors (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        organization TEXT,
        specialty TEXT,
        phone TEXT,
        wilaya TEXT,
        tier TEXT,
        status TEXT,
        latitude REAL,
        longitude REAL,
        assignedRepName TEXT
      )
    ''');

    // Offline Visits Queue Table
    await db.execute('''
      CREATE TABLE offline_visits (
        client_uuid TEXT PRIMARY KEY,
        doctor_id INTEGER,
        account_name TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        rep_name TEXT NOT NULL,
        rep_id TEXT NOT NULL,
        purpose TEXT,
        products_discussed TEXT,
        samples_distributed TEXT,
        gifts_distributed TEXT,
        feedback_notes TEXT,
        next_followup_date TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    // Cached Products Table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT,
        generic_name TEXT,
        dosage_form TEXT,
        strength TEXT,
        box_size TEXT,
        unit_price_da TEXT,
        dnh_status TEXT,
        is_sample INTEGER DEFAULT 0
      )
    ''');

    // Cached Sample Batches Table
    await db.execute('''
      CREATE TABLE sample_batches (
        id INTEGER PRIMARY KEY,
        prod_id TEXT NOT NULL,
        brand_name TEXT NOT NULL,
        expiry TEXT,
        quantity INTEGER DEFAULT 0,
        unit TEXT DEFAULT 'boîte'
      )
    ''');

    // Cached Promotional Gifts Table
    await db.execute('''
      CREATE TABLE promotional_gifts (
        id INTEGER PRIMARY KEY,
        gift_id TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER DEFAULT 0,
        distributed INTEGER DEFAULT 0
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT,
          generic_name TEXT,
          dosage_form TEXT,
          strength TEXT,
          box_size TEXT,
          unit_price_da TEXT,
          dnh_status TEXT,
          is_sample INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sample_batches (
          id INTEGER PRIMARY KEY,
          prod_id TEXT NOT NULL,
          brand_name TEXT NOT NULL,
          expiry TEXT,
          quantity INTEGER DEFAULT 0,
          unit TEXT DEFAULT 'boîte'
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS promotional_gifts (
          id INTEGER PRIMARY KEY,
          gift_id TEXT NOT NULL,
          name TEXT NOT NULL,
          quantity INTEGER DEFAULT 0,
          distributed INTEGER DEFAULT 0
        )
      ''');
    }
  }

  // --- Offline Visits Queue Operations ---
  Future<void> enqueueVisit(Map<String, dynamic> visitData) async {
    final db = await instance.database;
    await db.insert(
      'offline_visits',
      visitData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingVisits() async {
    final db = await instance.database;
    return await db.query(
      'offline_visits',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<int> markVisitSynced(String clientUuid) async {
    final db = await instance.database;
    return await db.update(
      'offline_visits',
      {'sync_status': 'synced'},
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
    );
  }

  Future<int> clearSyncedVisits() async {
    final db = await instance.database;
    return await db.delete(
      'offline_visits',
      where: 'sync_status = ?',
      whereArgs: ['synced'],
    );
  }

  // --- Local Doctors Cache ---
  Future<void> cacheDoctors(List<Doctor> doctors) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var doc in doctors) {
      batch.insert(
        'doctors',
        doc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Doctor>> getCachedDoctors() async {
    final db = await instance.database;
    final result = await db.query('doctors', orderBy: 'name ASC');
    return result.map((json) => Doctor.fromJson(json)).toList();
  }

  // --- Local Products, Samples & Gifts Cache ---
  Future<void> cacheCatalog({
    required List<Product> products,
    required List<SampleBatch> samples,
    required List<PromotionalGift> gifts,
  }) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var p in products) {
      batch.insert('products', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (var s in samples) {
      batch.insert('sample_batches', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (var g in gifts) {
      batch.insert('promotional_gifts', g.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Product>> getCachedProducts() async {
    final db = await instance.database;
    final result = await db.query('products', orderBy: 'name ASC');
    return result.map((row) => Product.fromMap(row)).toList();
  }

  Future<List<SampleBatch>> getCachedSamples() async {
    final db = await instance.database;
    final result = await db.query('sample_batches', orderBy: 'brand_name ASC');
    return result.map((row) => SampleBatch.fromMap(row)).toList();
  }

  Future<List<PromotionalGift>> getCachedGifts() async {
    final db = await instance.database;
    final result = await db.query('promotional_gifts', orderBy: 'name ASC');
    return result.map((row) => PromotionalGift.fromMap(row)).toList();
  }
}
