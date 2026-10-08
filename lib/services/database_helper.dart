import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/doctor.dart';

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
      version: 1,
      onCreate: _createDB,
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
}
