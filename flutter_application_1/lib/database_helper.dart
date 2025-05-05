import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io' as io;

class DatabaseHelper {
  static Database? _db;

  Future<Database?> get db async {
    if (_db != null) {
      return _db;
    }
    _db = await initDatabase();
    return _db;
  }

  Future<Database> initDatabase() async {
  io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
  String pathToFile = path.join(documentsDirectory.path, 'geofotos.db');
  var db = await openDatabase(pathToFile, version: 1, onCreate: _onCreate);
  return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filePath TEXT,
        latitude REAL,
        longitude REAL,
        timestamp INTEGER
      )
    ''');
  }

  Future<int> insertPhoto(Map<String, dynamic> photo) async {
    var dbClient = await db;
    if (dbClient == null) return -1;
    return await dbClient.insert('photos', photo);
  }

  Future<List<Map<String, dynamic>>> getPhotos() async {
    var dbClient = await db;
    if (dbClient == null) return [];
    return await dbClient.query('photos');
  }

  // Puedes agregar más métodos para actualizar, eliminar o consultar fotos por ubicación, etc.
}