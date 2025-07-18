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
      version: 5, // Increment version for context settings
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
        embedding TEXT,
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

    // Create conversations table
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_active INTEGER DEFAULT 0,
        context_settings TEXT DEFAULT NULL
      )
    ''');

    // Create conversation messages table
    await db.execute('''
      CREATE TABLE conversation_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        token_count INTEGER DEFAULT 0,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
      )
    ''');

    // Create default folders
    await _createDefaultFolders(db);
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add embedding column to existing files table
      await db.execute('ALTER TABLE files ADD COLUMN embedding TEXT');
      print('Database upgraded: Added embedding column');
    }
    if (oldVersion < 3) {
      // Version 3 upgrade: user profile table was added but is now deprecated
      // No longer needed as profile uses file system instead
      print('Database upgraded: Profile now uses file system');
    }
    if (oldVersion < 4) {
      // Version 4 upgrade: Add conversations tables
      await db.execute('''
        CREATE TABLE conversations (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_active INTEGER DEFAULT 0
        )
      ''');
      
      await db.execute('''
        CREATE TABLE conversation_messages (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL,
          token_count INTEGER DEFAULT 0,
          FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
        )
      ''');
      
      print('Database upgraded: Added conversations tables');
    }
    if (oldVersion < 5) {
      // Version 5 upgrade: Add context settings to conversations
      await db.execute('ALTER TABLE conversations ADD COLUMN context_settings TEXT DEFAULT NULL');
      print('Database upgraded: Added context settings to conversations');
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
    
    // Create special profile file
    await _createProfileFile(db);
  }

  Future<void> _createProfileFile(Database db) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final profileContent = '''# Profile

Who are you? What are your goals, mission, focus areas?

This information helps the AI understand your context and provide more personalized responses.

---

<!-- Edit this file to add your personal information -->
''';
    
    // Create profile file with specific ID
    const profileId = 'profile_special_file';
    final filePath = join(documentsDir.path, 'journal_files', '$profileId.md');
    
    // Ensure the directory exists
    final fileDir = Directory(dirname(filePath));
    if (!await fileDir.exists()) {
      await fileDir.create(recursive: true);
    }
    
    // Write content to file
    final file = File(filePath);
    await file.writeAsString(profileContent);
    
    // Create database entry
    final profileFile = JournalFile(
      id: profileId,
      name: 'Profile',
      folderId: null,
      filePath: filePath,
      content: profileContent,
      wordCount: JournalFile.calculateWordCount(profileContent),
    );
    
    await db.insert('files', profileFile.toMap());
    
    // Update search index
    await db.insert('files_fts', {
      'file_id': profileId,
      'title': 'Profile',
      'content': profileContent,
    });
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

  // Simple embedding storage
  Future<void> storeEmbedding(String fileId, List<double> embedding) async {
    final db = await database;
    final embeddingJson = embedding.join(',');
    await db.update(
      'files',
      {'embedding': embeddingJson},
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }

  // Get files with embeddings for similarity search
  Future<List<JournalFile>> getFilesWithEmbeddings({DateTime? beforeDate}) async {
    final db = await database;
    String whereClause = 'embedding IS NOT NULL';
    List<dynamic> whereArgs = [];
    
    if (beforeDate != null) {
      whereClause += ' AND updated_at < ?';
      whereArgs.add(beforeDate.toIso8601String());
    }
    
    final maps = await db.query(
      'files',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
    
    return maps.map((map) => JournalFile.fromMap(map)).toList();
  }

  // Get recent files ordered by date
  Future<List<JournalFile>> getRecentFilesOrdered({
    int? maxTokens,
    DateTime? sinceDate,  // NEW: filter by date
    DateTime? beforeDate, // NEW: filter by date range
  }) async {
    final db = await database;
    
    String whereClause = '1=1'; // Always true
    List<dynamic> whereArgs = [];
    
    if (sinceDate != null) {
      whereClause += ' AND updated_at >= ?';
      whereArgs.add(sinceDate.toIso8601String());
    }
    
    if (beforeDate != null) {
      whereClause += ' AND updated_at < ?';
      whereArgs.add(beforeDate.toIso8601String());
    }
    
    final maps = await db.query(
      'files',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );
    
    final files = <JournalFile>[];
    int totalTokens = 0;
    
    for (final map in maps) {
      final file = JournalFile.fromMap(map);
      
      // Load actual file content
      try {
        final content = await File(file.filePath).readAsString();
        final fileWithContent = file.copyWith(content: content);
        
        // Check token limit if specified
        if (maxTokens != null) {
          final contentTokens = _estimateTokens(content);
          if (totalTokens + contentTokens > maxTokens) {
            break;
          }
          totalTokens += contentTokens;
        }
        
        files.add(fileWithContent);
      } catch (e) {
        print('Error loading file content for ${file.filePath}: $e');
        // Skip files we can't read
        continue;
      }
    }
    
    return files;
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

  // Conversation operations
  Future<String> createConversation(String title) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();
    
    await db.insert('conversations', {
      'id': id,
      'title': title,
      'created_at': now,
      'updated_at': now,
      'is_active': 0,
    });
    
    return id;
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;
    return await db.query(
      'conversations',
      orderBy: 'updated_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getConversation(String id) async {
    final db = await database;
    final results = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isEmpty ? null : results.first;
  }

  Future<void> updateConversation(String id, {String? title}) async {
    final db = await database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (title != null) {
      updates['title'] = title;
    }
    
    await db.update(
      'conversations',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateConversationContextSettings(String id, dynamic contextSettings) async {
    final db = await database;
    
    // Convert context settings to simple key-value string format
    String? contextSettingsString;
    if (contextSettings != null) {
      final json = contextSettings.toJson();
      final pairs = <String>[];
      json.forEach((key, value) {
        if (value != null) {
          String valueString;
          if (value is List) {
            valueString = value.join(',');
          } else {
            valueString = value.toString();
          }
          pairs.add('${Uri.encodeComponent(key)}=${Uri.encodeComponent(valueString)}');
        }
      });
      contextSettingsString = pairs.join('&');
    }
    
    await db.update(
      'conversations',
      {
        'context_settings': contextSettingsString,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteConversation(String id) async {
    final db = await database;
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setActiveConversation(String id) async {
    final db = await database;
    
    // First, set all conversations to inactive
    await db.update(
      'conversations',
      {'is_active': 0},
    );
    
    // Then set the specified conversation to active
    await db.update(
      'conversations',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> getActiveConversationId() async {
    final db = await database;
    final results = await db.query(
      'conversations',
      where: 'is_active = 1',
      limit: 1,
    );
    return results.isEmpty ? null : results.first['id'] as String?;
  }

  // Conversation message operations
  Future<void> addConversationMessage(String conversationId, String role, String content) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();
    
    await db.insert('conversation_messages', {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'created_at': now,
      'token_count': _estimateTokens(content),
    });
    
    // Update conversation updated_at
    await db.update(
      'conversations',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<List<Map<String, dynamic>>> getConversationMessages(String conversationId) async {
    final db = await database;
    return await db.query(
      'conversation_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> clearConversationMessages(String conversationId) async {
    final db = await database;
    await db.delete(
      'conversation_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> trimConversationMessages(String conversationId, int maxMessages) async {
    final db = await database;
    
    // Get total message count
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM conversation_messages WHERE conversation_id = ?',
      [conversationId],
    );
    
    final messageCount = countResult.first['count'] as int;
    
    if (messageCount > maxMessages) {
      // Get the oldest messages to delete
      final messagesToDelete = await db.query(
        'conversation_messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC',
        limit: messageCount - maxMessages,
      );
      
      // Delete the oldest messages
      for (final message in messagesToDelete) {
        await db.delete(
          'conversation_messages',
          where: 'id = ?',
          whereArgs: [message['id']],
        );
      }
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Estimate token count for content (same logic as InsightsService)
  int _estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    
    // More accurate token estimation:
    // - Count words and punctuation separately
    // - Average English word is ~1.3 tokens
    // - Punctuation and spaces add overhead
    final words = text.trim().split(RegExp(r'\s+'));
    final wordTokens = (words.length * 1.3).ceil();
    
    // Add overhead for formatting, punctuation, etc.
    final overhead = (text.length * 0.1).ceil();
    
    return wordTokens + overhead;
  }

  /// Get the special profile file for AI context
  Future<JournalFile?> getProfileFile() async {
    const profileId = 'profile_special_file';
    return await getFile(profileId);
  }

  /// Ensure profile file exists (for existing users)
  Future<void> ensureProfileFileExists() async {
    const profileId = 'profile_special_file';
    final existingFile = await getFile(profileId);
    
    if (existingFile == null) {
      final db = await database;
      await _createProfileFile(db);
    }
  }
}