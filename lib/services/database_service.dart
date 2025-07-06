import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/journal_file.dart';
import '../models/journal_folder.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'isla_journal.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create folders table
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');

    // Create files table
    await db.execute('''
      CREATE TABLE files (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        folder_id TEXT,
        file_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_opened TEXT,
        word_count INTEGER DEFAULT 0,
        FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE SET NULL
      )
    ''');

    // Create search index using FTS5
    await db.execute('''
      CREATE VIRTUAL TABLE files_fts USING fts5(
        file_id,
        title,
        content,
        content='',
        contentless_delete=1
      )
    ''');

    // Create default folders
    await _createDefaultFolders(db);
  }

  Future<void> _createDefaultFolders(Database db) async {
    final defaultFolders = [
      {'name': 'Personal', 'id': 'personal'},
      {'name': 'Work', 'id': 'work'},
      {'name': 'Ideas', 'id': 'ideas'},
    ];

    for (final folder in defaultFolders) {
      final journalFolder = JournalFolder(
        id: folder['id'],
        name: folder['name']!,
      );
      await db.insert('folders', journalFolder.toMap());
    }
  }

  // Folder operations
  Future<String> createFolder(String name, {String? parentId}) async {
    final db = await database;
    final folder = JournalFolder(name: name, parentId: parentId);
    await db.insert('folders', folder.toMap());
    return folder.id;
  }

  Future<List<JournalFolder>> getFolders({String? parentId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      where: parentId != null ? 'parent_id = ?' : 'parent_id IS NULL',
      whereArgs: parentId != null ? [parentId] : null,
      orderBy: 'name ASC',
    );
    return maps.map((map) => JournalFolder.fromMap(map)).toList();
  }

  Future<JournalFolder?> getFolder(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return JournalFolder.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateFolder(JournalFolder folder) async {
    final db = await database;
    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> deleteFolder(String id) async {
    final db = await database;
    // First, move all files in this folder to the parent folder
    await db.execute('''
      UPDATE files 
      SET folder_id = (
        SELECT parent_id 
        FROM folders 
        WHERE id = ?
      )
      WHERE folder_id = ?
    ''', [id, id]);
    
    // Delete the folder
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // File operations
  Future<String> createFile(String name, String content, {String? folderId}) async {
    final db = await database;
    final documentsDir = await getApplicationDocumentsDirectory();
    final filePath = join(documentsDir.path, 'journal_files', '$name.md');
    
    // Ensure the directory exists
    final fileDir = Directory(dirname(filePath));
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
    }
    
    // Write content to file
    final file = File(filePath);
    await file.writeAsString(content);
    
    // Create database entry
    final journalFile = JournalFile(
      name: name,
      folderId: folderId,
      filePath: filePath,
      content: content,
      wordCount: JournalFile.calculateWordCount(content),
    );
    
    await db.insert('files', journalFile.toMap());
    
    // Update search index
    await db.insert('files_fts', {
      'file_id': journalFile.id,
      'title': name,
      'content': content,
    });
    
    return journalFile.id;
  }

  Future<List<JournalFile>> getFiles({String? folderId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'files',
      where: folderId != null ? 'folder_id = ?' : 'folder_id IS NULL',
      whereArgs: folderId != null ? [folderId] : null,
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => JournalFile.fromMap(map)).toList();
  }

  Future<JournalFile?> getFile(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'files',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final file = JournalFile.fromMap(maps.first);
      // Read content from file system
      final fileContent = await File(file.filePath).readAsString();
      return file.copyWith(content: fileContent);
    }
    return null;
  }

  Future<void> updateFile(JournalFile file) async {
    final db = await database;
    
    // Update file on disk
    await File(file.filePath).writeAsString(file.content);
    
    // Update database
    await db.update(
      'files',
      file.toMap(),
      where: 'id = ?',
      whereArgs: [file.id],
    );
    
    // Update search index
    await db.update(
      'files_fts',
      {
        'title': file.name,
        'content': file.content,
      },
      where: 'file_id = ?',
      whereArgs: [file.id],
    );
  }

  Future<void> deleteFile(String id) async {
    final db = await database;
    final file = await getFile(id);
    if (file != null) {
      // Delete file from disk
      final diskFile = File(file.filePath);
      if (await diskFile.exists()) {
        await diskFile.delete();
      }
      
      // Delete from database
      await db.delete('files', where: 'id = ?', whereArgs: [id]);
      
      // Delete from search index
      await db.delete('files_fts', where: 'file_id = ?', whereArgs: [id]);
    }
  }

  // Search operations
  Future<List<JournalFile>> searchFiles(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT f.* FROM files f
      JOIN files_fts fts ON f.id = fts.file_id
      WHERE files_fts MATCH ?
      ORDER BY rank
    ''', [query]);
    
    return maps.map((map) => JournalFile.fromMap(map)).toList();
  }

  // Recent files
  Future<List<JournalFile>> getRecentFiles({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'files',
      where: 'last_opened IS NOT NULL',
      orderBy: 'last_opened DESC',
      limit: limit,
    );
    return maps.map((map) => JournalFile.fromMap(map)).toList();
  }

  Future<void> updateLastOpened(String fileId) async {
    final db = await database;
    await db.update(
      'files',
      {'last_opened': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}