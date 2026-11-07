import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/location_record.dart';

class LocalDatabase {
  static const maxPendingLocations = 10000;
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  Database? _database;

  Future<Database> get database async {
    return _database ??= await _openDatabase();
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    return openDatabase(
      join(databasePath, 'ecoconnect.db'),
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE location_queue (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL NOT NULL,
            recorded_at INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await database.execute(
          'CREATE INDEX location_queue_user_time '
          'ON location_queue(user_id, recorded_at)',
        );
      },
    );
  }

  Future<void> enqueueLocation(LocationRecord record) async {
    final database = await this.database;
    await database.transaction((transaction) async {
      await transaction.insert(
        'location_queue',
        record.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await transaction.rawDelete('''
        DELETE FROM location_queue
        WHERE rowid IN (
          SELECT rowid FROM location_queue
          ORDER BY recorded_at ASC
          LIMIT MAX(0, (SELECT COUNT(*) FROM location_queue) - ?)
        )
      ''', [maxPendingLocations]);
    });
  }

  Future<List<LocationRecord>> pendingLocations(String userId) async {
    final database = await this.database;
    final rows = await database.query(
      'location_queue',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(LocationRecord.fromDatabase).toList();
  }

  Future<void> deleteLocations(Iterable<String> ids) async {
    final idsList = ids.toList();
    if (idsList.isEmpty) return;

    final database = await this.database;
    await database.transaction((transaction) async {
      for (final id in idsList) {
        await transaction.delete(
          'location_queue',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> incrementRetryCount(Iterable<String> ids) async {
    final idsList = ids.toList();
    if (idsList.isEmpty) return;

    final database = await this.database;
    await database.transaction((transaction) async {
      for (final id in idsList) {
        await transaction.rawUpdate(
          'UPDATE location_queue SET retry_count = retry_count + 1 '
          'WHERE id = ?',
          [id],
        );
      }
    });
  }

  Future<int> pendingCount(String userId) async {
    final database = await this.database;
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM location_queue WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
