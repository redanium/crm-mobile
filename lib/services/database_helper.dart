import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/doctor.dart';
import '../models/product.dart';
import '../models/visit.dart';

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
      version: 10,
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
        product_quantities TEXT,
        samples_distributed TEXT,
        gifts_distributed TEXT,
        inventory_distributions TEXT,
        proof_documents TEXT,
        feedback_notes TEXT,
        next_followup_date TEXT,
        latitude REAL,
        longitude REAL,
        wilaya TEXT,
        facility_name TEXT,
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
        initial_quantity INTEGER DEFAULT 0,
        unit TEXT DEFAULT 'boîte',
        is_allocated INTEGER DEFAULT 0
      )
    ''');

    // Cached Promotional Gifts Table
    await db.execute('''
      CREATE TABLE promotional_gifts (
        id INTEGER PRIMARY KEY,
        gift_id TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER DEFAULT 0,
        initial_quantity INTEGER DEFAULT 0,
        distributed INTEGER DEFAULT 0,
        is_allocated INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        movement_id TEXT PRIMARY KEY,
        item_type TEXT,
        item_name TEXT,
        movement_type TEXT,
        quantity INTEGER DEFAULT 0,
        created_at TEXT,
        source_name TEXT,
        destination_name TEXT,
        notes TEXT
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
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE offline_visits ADD COLUMN wilaya TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE offline_visits ADD COLUMN facility_name TEXT;');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE offline_visits ADD COLUMN inventory_distributions TEXT;'); } catch (_) {}
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE sample_batches ADD COLUMN is_allocated INTEGER DEFAULT 0;'); } catch (_) {}
      try { await db.execute('ALTER TABLE promotional_gifts ADD COLUMN is_allocated INTEGER DEFAULT 0;'); } catch (_) {}
    }
    if (oldVersion < 6) {
      await db.execute('''CREATE TABLE IF NOT EXISTS stock_movements (
        movement_id TEXT PRIMARY KEY,
        item_type TEXT,
        item_name TEXT,
        movement_type TEXT,
        quantity INTEGER DEFAULT 0,
        created_at TEXT,
        source_name TEXT,
        destination_name TEXT,
        notes TEXT
      )''');
    }
    if (oldVersion < 7) {
      for (final column in ['source_name', 'destination_name', 'notes']) {
        try { await db.execute('ALTER TABLE stock_movements ADD COLUMN $column TEXT;'); } catch (_) {}
      }
    }
    if (oldVersion < 8) {
      for (final table in ['sample_batches', 'promotional_gifts']) {
        try { await db.execute('ALTER TABLE $table ADD COLUMN initial_quantity INTEGER DEFAULT 0;'); } catch (_) {}
      }
    }
    if (oldVersion < 9) {
      try { await db.execute('ALTER TABLE offline_visits ADD COLUMN proof_documents TEXT;'); } catch (_) {}
    }
    if (oldVersion < 10) {
      try { await db.execute('ALTER TABLE offline_visits ADD COLUMN product_quantities TEXT;'); } catch (_) {}
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

  /// Get all visits from SQLite (both pending and synced, sorted newest first)
  Future<List<Visit>> getAllVisits() async {
    final db = await instance.database;
    final results = await db.query(
      'offline_visits',
      orderBy: 'created_at DESC',
    );
    return results.map((row) => Visit.fromJson(row)).toList();
  }

  /// Cache visits fetched from server into SQLite
  Future<void> cacheVisits(List<Visit> visits) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var v in visits) {
      final uuid = v.clientUuid ?? 'srv-${v.id ?? DateTime.now().millisecondsSinceEpoch}';
      batch.insert(
        'offline_visits',
        {
          'client_uuid': uuid,
          'account_name': v.accountName,
          'activity_type': v.activityType,
          'rep_name': v.repName,
          'rep_id': v.repId,
          'purpose': v.purpose,
          'products_discussed': v.productsDiscussed,
          'product_quantities': jsonEncode(v.productQuantities),
          'samples_distributed': v.samplesDistributed,
          'gifts_distributed': v.giftsDistributed,
          'feedback_notes': v.feedbackNotes,
          'next_followup_date': v.nextFollowupDate,
          'latitude': v.latitude,
          'longitude': v.longitude,
          'wilaya': v.wilaya,
          'facility_name': v.facilityName,
          'created_at': v.scheduledAt.toIso8601String(),
          'sync_status': v.status.isNotEmpty ? v.status : 'synced',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
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

  Future<void> cacheStockMovements(List<Map<String, dynamic>> movements) async {
    final db = await instance.database;
    await db.delete('stock_movements');
    final batch = db.batch();
    for (final movement in movements) {
      batch.insert('stock_movements', {
        'movement_id': movement['id'].toString(),
        'item_type': movement['itemType']?.toString() ?? '',
        'item_name': movement['itemName']?.toString() ?? '',
        'movement_type': movement['movementType']?.toString() ?? '',
        'quantity': movement['quantity'] is int ? movement['quantity'] : int.tryParse(movement['quantity']?.toString() ?? '0') ?? 0,
        'created_at': movement['createdAt']?.toString() ?? '',
        'source_name': movement['sourceName']?.toString(),
        'destination_name': movement['destinationName']?.toString(),
        'notes': movement['notes']?.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedStockMovements() async {
    final db = await instance.database;
    return db.query('stock_movements', orderBy: 'created_at DESC', limit: 50);
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
