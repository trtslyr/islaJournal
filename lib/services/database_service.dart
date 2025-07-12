import 'dart:async';
import 'dart:convert';
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
      version: 3,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
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

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add embeddings table for RAG system
      await db.execute('''
        CREATE TABLE file_embeddings (
          id TEXT PRIMARY KEY,
          file_id TEXT NOT NULL,
          embedding BLOB NOT NULL,
          embedding_version INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          chunk_index INTEGER DEFAULT 0,
          chunk_text TEXT,
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
        )
      ''');

      // Add imported_documents table for PDF/external data
      await db.execute('''
        CREATE TABLE imported_documents (
          id TEXT PRIMARY KEY,
          original_filename TEXT NOT NULL,
          file_path TEXT NOT NULL,
          content_type TEXT NOT NULL,
          total_pages INTEGER DEFAULT 1,
          import_date TEXT NOT NULL,
          source_type TEXT NOT NULL,
          metadata TEXT,
          word_count INTEGER DEFAULT 0,
          processed_at TEXT
        )
      ''');

      // Add imported_content table for chunked content from imported docs
      await db.execute('''
        CREATE TABLE imported_content (
          id TEXT PRIMARY KEY,
          document_id TEXT NOT NULL,
          chunk_index INTEGER NOT NULL,
          content TEXT NOT NULL,
          page_number INTEGER,
          created_at TEXT NOT NULL,
          word_count INTEGER DEFAULT 0,
          FOREIGN KEY (document_id) REFERENCES imported_documents (id) ON DELETE CASCADE
        )
      ''');

      // Add index for better performance
      await db.execute('CREATE INDEX idx_file_embeddings_file_id ON file_embeddings(file_id)');
      await db.execute('CREATE INDEX idx_imported_content_document_id ON imported_content(document_id)');
    }
    
    if (oldVersion < 3) {
      // Phase 3 AI Features: Tags, Mood Analysis, Themes, Analytics
      
      // Tags system
      await db.execute('''
        CREATE TABLE tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color TEXT,
          description TEXT,
          created_at TEXT NOT NULL,
          usage_count INTEGER DEFAULT 0
        )
      ''');
      
      await db.execute('''
        CREATE TABLE file_tags (
          id TEXT PRIMARY KEY,
          file_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          confidence REAL DEFAULT 1.0,
          source TEXT DEFAULT 'manual',
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE,
          UNIQUE(file_id, tag_id)
        )
      ''');
      
      // Mood analysis data
      await db.execute('''
        CREATE TABLE mood_entries (
          id TEXT PRIMARY KEY,
          file_id TEXT NOT NULL,
          valence REAL NOT NULL,
          arousal REAL NOT NULL,
          emotions TEXT,
          confidence REAL DEFAULT 0.0,
          analysis_version INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          metadata TEXT,
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
        )
      ''');
      
      // Themes/topics system
      await db.execute('''
        CREATE TABLE themes (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          category TEXT,
          description TEXT,
          created_at TEXT NOT NULL,
          usage_count INTEGER DEFAULT 0,
          parent_theme_id TEXT,
          FOREIGN KEY (parent_theme_id) REFERENCES themes (id) ON DELETE SET NULL
        )
      ''');
      
      await db.execute('''
        CREATE TABLE file_themes (
          id TEXT PRIMARY KEY,
          file_id TEXT NOT NULL,
          theme_id TEXT NOT NULL,
          relevance_score REAL DEFAULT 0.0,
          created_at TEXT NOT NULL,
          source TEXT DEFAULT 'ai_generated',
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE,
          FOREIGN KEY (theme_id) REFERENCES themes (id) ON DELETE CASCADE,
          UNIQUE(file_id, theme_id)
        )
      ''');
      
      // Analytics and insights data
      await db.execute('''
        CREATE TABLE analytics_data (
          id TEXT PRIMARY KEY,
          file_id TEXT,
          metric_type TEXT NOT NULL,
          metric_value REAL NOT NULL,
          metric_metadata TEXT,
          date_recorded TEXT NOT NULL,
          period_type TEXT DEFAULT 'daily',
          created_at TEXT NOT NULL,
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
        )
      ''');
      
      // Writing sessions for pattern tracking
      await db.execute('''
        CREATE TABLE writing_sessions (
          id TEXT PRIMARY KEY,
          file_id TEXT,
          start_time TEXT NOT NULL,
          end_time TEXT,
          words_written INTEGER DEFAULT 0,
          characters_written INTEGER DEFAULT 0,
          session_duration INTEGER DEFAULT 0,
          mood_before REAL,
          mood_after REAL,
          productivity_score REAL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE SET NULL
        )
      ''');
      
      // Indexes for better performance
      await db.execute('CREATE INDEX idx_file_tags_file_id ON file_tags(file_id)');
      await db.execute('CREATE INDEX idx_file_tags_tag_id ON file_tags(tag_id)');
      await db.execute('CREATE INDEX idx_mood_entries_file_id ON mood_entries(file_id)');
      await db.execute('CREATE INDEX idx_mood_entries_created_at ON mood_entries(created_at)');
      await db.execute('CREATE INDEX idx_file_themes_file_id ON file_themes(file_id)');
      await db.execute('CREATE INDEX idx_file_themes_theme_id ON file_themes(theme_id)');
      await db.execute('CREATE INDEX idx_analytics_data_metric_type ON analytics_data(metric_type)');
      await db.execute('CREATE INDEX idx_analytics_data_date_recorded ON analytics_data(date_recorded)');
      await db.execute('CREATE INDEX idx_writing_sessions_file_id ON writing_sessions(file_id)');
      await db.execute('CREATE INDEX idx_writing_sessions_start_time ON writing_sessions(start_time)');
      
      // Create some default tags and themes
      await _createDefaultTagsAndThemes(db);
    }
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

  Future<void> _createDefaultTagsAndThemes(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // Default tags
    final defaultTags = [
      {'name': 'Personal', 'color': '#4A90E2', 'description': 'Personal thoughts and reflections'},
      {'name': 'Work', 'color': '#F5A623', 'description': 'Work-related entries'},
      {'name': 'Goals', 'color': '#7ED321', 'description': 'Goal setting and achievement'},
      {'name': 'Reflection', 'color': '#9013FE', 'description': 'Deep thoughts and self-reflection'},
      {'name': 'Gratitude', 'color': '#FF6B6B', 'description': 'Things to be grateful for'},
      {'name': 'Memories', 'color': '#4ECDC4', 'description': 'Special memories and experiences'},
      {'name': 'Ideas', 'color': '#95E1D3', 'description': 'Creative ideas and inspiration'},
      {'name': 'Learning', 'color': '#F38BA8', 'description': 'Learning experiences and insights'},
    ];

    for (final tag in defaultTags) {
      await db.insert('tags', {
        'id': 'tag_${tag['name']!.toLowerCase()}',
        'name': tag['name'],
        'color': tag['color'],
        'description': tag['description'],
        'created_at': now,
        'usage_count': 0,
      });
    }

    // Default themes
    final defaultThemes = [
      {'name': 'Self-Discovery', 'category': 'Personal Growth', 'description': 'Exploring identity and personal insights'},
      {'name': 'Relationships', 'category': 'Social', 'description': 'Family, friends, and social connections'},
      {'name': 'Career & Ambition', 'category': 'Professional', 'description': 'Work goals and professional development'},
      {'name': 'Health & Wellness', 'category': 'Lifestyle', 'description': 'Physical and mental health topics'},
      {'name': 'Creativity & Art', 'category': 'Creative', 'description': 'Creative pursuits and artistic expression'},
      {'name': 'Daily Life', 'category': 'Routine', 'description': 'Everyday experiences and observations'},
      {'name': 'Challenges & Growth', 'category': 'Personal Growth', 'description': 'Overcoming obstacles and learning'},
      {'name': 'Dreams & Aspirations', 'category': 'Future', 'description': 'Future goals and aspirations'},
    ];

    for (final theme in defaultThemes) {
      await db.insert('themes', {
        'id': 'theme_${theme['name']!.toLowerCase().replaceAll(' ', '_').replaceAll('&', 'and')}',
        'name': theme['name'],
        'category': theme['category'],
        'description': theme['description'],
        'created_at': now,
        'usage_count': 0,
      });
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
    final List<Map<String, dynamic>> maps;
    
    if (parentId == null) {
      // Get all folders
      maps = await db.query(
        'folders',
        orderBy: 'name ASC',
      );
    } else {
      // Get folders with specific parent
      maps = await db.query(
        'folders',
        where: 'parent_id = ?',
        whereArgs: [parentId],
        orderBy: 'name ASC',
      );
    }
    
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
    
    // Create database entry first to get the ID
    final journalFile = JournalFile(
      name: name,
      folderId: folderId,
      filePath: '', // Will be set after creating the path
      content: content,
      wordCount: JournalFile.calculateWordCount(content),
    );
    
    final filePath = join(documentsDir.path, 'journal_files', '${journalFile.id}.md');
    
    // Ensure the directory exists
    final fileDir = Directory(dirname(filePath));
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
    }
    
    // Write content to file
    final file = File(filePath);
    await file.writeAsString(content);
    
    // Update the file path in the journal file
    final updatedJournalFile = journalFile.copyWith(filePath: filePath);
    
    await db.insert('files', updatedJournalFile.toMap());
    
    // Update search index
    await db.insert('files_fts', {
      'file_id': updatedJournalFile.id,
      'title': name,
      'content': content,
    });
    
    return updatedJournalFile.id;
  }

  Future<List<JournalFile>> getFiles({String? folderId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;
    
    if (folderId == null) {
      // Get all files
      maps = await db.query(
        'files',
        orderBy: 'updated_at DESC',
      );
    } else {
      // Get files in specific folder
      maps = await db.query(
        'files',
        where: 'folder_id = ?',
        whereArgs: [folderId],
        orderBy: 'updated_at DESC',
      );
    }
    
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

  // Tags operations
  Future<List<Map<String, dynamic>>> getTags() async {
    final db = await database;
    return await db.query('tags', orderBy: 'usage_count DESC, name ASC');
  }

  Future<void> createTag(String name, {String? color, String? description}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('tags', {
      'id': 'tag_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'color': color ?? '#4A90E2',
      'description': description,
      'created_at': now,
      'usage_count': 0,
    });
  }

  Future<void> addFileTag(String fileId, String tagId, {double confidence = 1.0, String source = 'manual'}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('file_tags', {
      'id': 'ft_${DateTime.now().millisecondsSinceEpoch}',
      'file_id': fileId,
      'tag_id': tagId,
      'created_at': now,
      'confidence': confidence,
      'source': source,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Update tag usage count
    await db.rawUpdate('UPDATE tags SET usage_count = usage_count + 1 WHERE id = ?', [tagId]);
  }

  Future<List<Map<String, dynamic>>> getFileTags(String fileId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, ft.confidence, ft.source, ft.created_at as tagged_at
      FROM tags t
      JOIN file_tags ft ON t.id = ft.tag_id
      WHERE ft.file_id = ?
      ORDER BY ft.confidence DESC, t.name ASC
    ''', [fileId]);
  }

  Future<void> removeFileTag(String fileId, String tagId) async {
    final db = await database;
    await db.delete('file_tags', where: 'file_id = ? AND tag_id = ?', whereArgs: [fileId, tagId]);
    // Update tag usage count
    await db.rawUpdate('UPDATE tags SET usage_count = CASE WHEN usage_count > 0 THEN usage_count - 1 ELSE 0 END WHERE id = ?', [tagId]);
  }

  // Mood operations
  Future<void> saveMoodEntry(String fileId, double valence, double arousal, List<String> emotions, {double confidence = 0.0, Map<String, dynamic>? metadata}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('mood_entries', {
      'id': 'mood_${DateTime.now().millisecondsSinceEpoch}',
      'file_id': fileId,
      'valence': valence,
      'arousal': arousal,
      'emotions': emotions.join(','),
      'confidence': confidence,
      'analysis_version': 1,
      'created_at': now,
      'updated_at': now,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getMoodEntry(String fileId) async {
    final db = await database;
    final result = await db.query('mood_entries', where: 'file_id = ?', whereArgs: [fileId], orderBy: 'created_at DESC', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getMoodHistory({DateTime? startDate, DateTime? endDate, int? limit}) async {
    final db = await database;
    String query = 'SELECT * FROM mood_entries';
    List<dynamic> args = [];
    
    if (startDate != null || endDate != null) {
      query += ' WHERE ';
      if (startDate != null) {
        query += 'created_at >= ?';
        args.add(startDate.toIso8601String());
        if (endDate != null) {
          query += ' AND ';
        }
      }
      if (endDate != null) {
        query += 'created_at <= ?';
        args.add(endDate.toIso8601String());
      }
    }
    
    query += ' ORDER BY created_at DESC';
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }
    
    return await db.rawQuery(query, args);
  }

  // Themes operations
  Future<List<Map<String, dynamic>>> getThemes() async {
    final db = await database;
    return await db.query('themes', orderBy: 'usage_count DESC, name ASC');
  }

  Future<void> addFileTheme(String fileId, String themeId, double relevanceScore, {String source = 'ai_generated'}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('file_themes', {
      'id': 'fth_${DateTime.now().millisecondsSinceEpoch}',
      'file_id': fileId,
      'theme_id': themeId,
      'relevance_score': relevanceScore,
      'created_at': now,
      'source': source,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Update theme usage count
    await db.rawUpdate('UPDATE themes SET usage_count = usage_count + 1 WHERE id = ?', [themeId]);
  }

  Future<List<Map<String, dynamic>>> getFileThemes(String fileId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT th.*, fth.relevance_score, fth.source, fth.created_at as themed_at
      FROM themes th
      JOIN file_themes fth ON th.id = fth.theme_id
      WHERE fth.file_id = ?
      ORDER BY fth.relevance_score DESC, th.name ASC
    ''', [fileId]);
  }

  // Analytics operations
  Future<void> recordAnalyticsData(String metricType, double metricValue, {String? fileId, Map<String, dynamic>? metadata, String periodType = 'daily'}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('analytics_data', {
      'id': 'analytics_${DateTime.now().millisecondsSinceEpoch}',
      'file_id': fileId,
      'metric_type': metricType,
      'metric_value': metricValue,
      'metric_metadata': metadata != null ? jsonEncode(metadata) : null,
      'date_recorded': now,
      'period_type': periodType,
      'created_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getAnalyticsData(String metricType, {DateTime? startDate, DateTime? endDate, String? fileId}) async {
    final db = await database;
    String query = 'SELECT * FROM analytics_data WHERE metric_type = ?';
    List<dynamic> args = [metricType];
    
    if (fileId != null) {
      query += ' AND file_id = ?';
      args.add(fileId);
    }
    
    if (startDate != null) {
      query += ' AND date_recorded >= ?';
      args.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      query += ' AND date_recorded <= ?';
      args.add(endDate.toIso8601String());
    }
    
    query += ' ORDER BY date_recorded DESC';
    return await db.rawQuery(query, args);
  }

  // Writing sessions operations
  Future<String> startWritingSession(String? fileId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    
    await db.insert('writing_sessions', {
      'id': sessionId,
      'file_id': fileId,
      'start_time': now,
      'created_at': now,
    });
    
    return sessionId;
  }

  Future<void> endWritingSession(String sessionId, {int? wordsWritten, int? charactersWritten, double? moodAfter, double? productivityScore}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    // Get session start time to calculate duration
    final session = await db.query('writing_sessions', where: 'id = ?', whereArgs: [sessionId]);
    if (session.isNotEmpty) {
      final startTime = DateTime.parse(session.first['start_time'] as String);
      final duration = DateTime.now().difference(startTime).inSeconds;
      
      await db.update('writing_sessions', {
        'end_time': now,
        'words_written': wordsWritten ?? 0,
        'characters_written': charactersWritten ?? 0,
        'session_duration': duration,
        'mood_after': moodAfter,
        'productivity_score': productivityScore,
      }, where: 'id = ?', whereArgs: [sessionId]);
    }
  }

  Future<List<Map<String, dynamic>>> getWritingSessions({DateTime? startDate, DateTime? endDate, String? fileId, int? limit}) async {
    final db = await database;
    String query = 'SELECT * FROM writing_sessions WHERE end_time IS NOT NULL';
    List<dynamic> args = [];
    
    if (fileId != null) {
      query += ' AND file_id = ?';
      args.add(fileId);
    }
    
    if (startDate != null) {
      query += ' AND start_time >= ?';
      args.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      query += ' AND start_time <= ?';
      args.add(endDate.toIso8601String());
    }
    
    query += ' ORDER BY start_time DESC';
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }
    
    return await db.rawQuery(query, args);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}