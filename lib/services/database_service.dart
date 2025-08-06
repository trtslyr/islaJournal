import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import '../models/journal_file.dart';
import '../models/journal_folder.dart';
import '../services/date_parsing_service.dart';

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
    
    // Use platform-specific database factory
    if (Platform.isWindows || Platform.isLinux) {
      // For Windows/Linux desktop platforms, use FFI (macOS works with regular sqflite)
      final databaseFactory = databaseFactoryFfi;
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: _createDatabase,
          onUpgrade: _upgradeDatabase,
        ),
      );
    } else {
      // For mobile platforms (iOS/Android) and macOS, use regular sqflite
      return await openDatabase(
        path,
        version: 12, // Keep current version but ensure compatibility
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );
    }
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
        is_pinned INTEGER DEFAULT 0,
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
        journal_date TEXT,
        summary TEXT,
        keywords TEXT,
        is_pinned INTEGER DEFAULT 0,
        FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE SET NULL
      )
    ''');

    // Create search index using FTS5 with error handling for compatibility
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE files_fts USING fts5(
          file_id,
          title,
          content
        )
      ''');
      debugPrint('✅ FTS5 search index created successfully');
    } catch (e) {
      debugPrint('⚠️ FTS5 not available on this system: $e');
      debugPrint('⚠️ Search functionality will be limited but app will work normally');
      // App will continue to work, just without full-text search
    }

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

    // Create import functionality tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_embeddings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        content TEXT NOT NULL,
        embedding BLOB NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_insights (
        file_id TEXT PRIMARY KEY,
        word_count INTEGER,
        tags TEXT,
        date TEXT,
        has_personal_content INTEGER,
        has_work_content INTEGER,
        sentiment TEXT,
        original_path TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_path TEXT NOT NULL,
        imported_file_id TEXT NOT NULL,
        imported_at TEXT NOT NULL,
        FOREIGN KEY (imported_file_id) REFERENCES files (id) ON DELETE CASCADE
      )
    ''');

    // Don't create default folders - only create year folders as needed during import
    // await _createDefaultFolders(db);
    
    // Create special profile file
    await _createProfileFile(db);
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Version 2 upgrade: Add conversations table
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
      
      debugPrint('Database upgraded: Added conversations and messages tables');
    }
    
    if (oldVersion < 4) {
      // Version 4 upgrade: Add context settings to conversations
      try {
        await db.execute('ALTER TABLE conversations ADD COLUMN context_settings TEXT DEFAULT NULL');
        debugPrint('Database upgraded: Added context settings to conversations');
      } catch (e) {
        debugPrint('Database upgrade: context_settings column already exists');
      }
    }
    if (oldVersion < 6) {
      // Version 6 upgrade: Add import functionality tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS file_embeddings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_id TEXT NOT NULL,
          chunk_index INTEGER NOT NULL,
          content TEXT NOT NULL,
          embedding BLOB NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS file_insights (
          file_id TEXT PRIMARY KEY,
          word_count INTEGER,
          tags TEXT,
          date TEXT,
          has_personal_content INTEGER,
          has_work_content INTEGER,
          sentiment TEXT,
          original_path TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS import_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_path TEXT NOT NULL,
          file_id TEXT NOT NULL,
          imported_at TEXT NOT NULL,
          FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
        )
      ''');
      
      debugPrint('Database upgraded: Added import functionality tables');
    }
    
    if (oldVersion < 7) {
      // Version 7 upgrade: Fix file_embeddings table schema
      try {
        // Drop the existing table if it exists with wrong schema
        await db.execute('DROP TABLE IF EXISTS file_embeddings');
        
        // Recreate with correct schema
        await db.execute('''
          CREATE TABLE file_embeddings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            content TEXT NOT NULL,
            embedding BLOB NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
          )
        ''');
        
        debugPrint('Database upgraded: Fixed file_embeddings table schema');
      } catch (e) {
        debugPrint('Error fixing file_embeddings table: $e');
      }
    }
    
    if (oldVersion < 8) {
      // Version 8 upgrade: Add journal_date field for chronological sorting
      try {
        await db.execute('ALTER TABLE files ADD COLUMN journal_date TEXT');
        debugPrint('Database upgraded: Added journal_date field for chronological sorting');
        
        // Backfill journal dates for existing files
        await _backfillJournalDates(db);
        debugPrint('Database upgraded: Backfilled journal dates for existing files');
      } catch (e) {
        debugPrint('Error adding journal_date field: $e');
      }
    }
    
    if (oldVersion < 9) {
      // Version 9 upgrade: Ensure journal_date field exists and backfill dates
      try {
        // Check if journal_date column exists
        final result = await db.rawQuery("PRAGMA table_info(files)");
        final hasJournalDate = result.any((column) => column['name'] == 'journal_date');
        
        if (!hasJournalDate) {
          await db.execute('ALTER TABLE files ADD COLUMN journal_date TEXT');
          debugPrint('Database upgraded v9: Added journal_date field');
        } else {
          debugPrint('Database upgraded v9: journal_date field already exists');
        }
        
        // Always run backfill to ensure existing files have dates
        await _backfillJournalDates(db);
        debugPrint('Database upgraded v9: Backfilled journal dates for existing files');
      } catch (e) {
        debugPrint('Error in v9 upgrade: $e');
      }
    }

    if (oldVersion < 10) {
      // Version 10 upgrade: Add summary and keywords fields for optimized context
      try {
        final result = await db.rawQuery("PRAGMA table_info(files)");
        final hasSummary = result.any((column) => column['name'] == 'summary');
        final hasKeywords = result.any((column) => column['name'] == 'keywords');
        
        if (!hasSummary) {
          await db.execute('ALTER TABLE files ADD COLUMN summary TEXT');
          debugPrint('Database upgraded v10: Added summary field');
        }
        
        if (!hasKeywords) {
          await db.execute('ALTER TABLE files ADD COLUMN keywords TEXT');
          debugPrint('Database upgraded v10: Added keywords field');
        }
        
        debugPrint('Database upgraded v10: Ready for optimized context system');
      } catch (e) {
        debugPrint('Error in v10 upgrade: $e');
      }
    }

    if (oldVersion < 11) {
      // Version 11 upgrade: Add is_pinned field for pinning files to AI context
      try {
        final result = await db.rawQuery("PRAGMA table_info(files)");
        final hasPinned = result.any((column) => column['name'] == 'is_pinned');
        
        if (!hasPinned) {
          await db.execute('ALTER TABLE files ADD COLUMN is_pinned INTEGER DEFAULT 0');
          debugPrint('Database upgraded v11: Added is_pinned field for file pinning');
        }
        
        debugPrint('Database upgraded v11: Pin functionality enabled');
      } catch (e) {
        debugPrint('Error in v11 upgrade: $e');
      }
    }

    if (oldVersion < 12) {
      // Version 12 upgrade: Add is_pinned field to folders table
      try {
        final result = await db.rawQuery("PRAGMA table_info(folders)");
        final hasPinned = result.any((column) => column['name'] == 'is_pinned');
        
        if (!hasPinned) {
          await db.execute('ALTER TABLE folders ADD COLUMN is_pinned INTEGER DEFAULT 0');
          debugPrint('Database upgraded v12: Added is_pinned field to folders');
        }
        
        debugPrint('Database upgraded v12: Folder pin functionality enabled');
      } catch (e) {
        debugPrint('Error in v12 upgrade: $e');
      }
    }


  }

  /// Backfill journal dates for existing files that don't have them
  Future<void> _backfillJournalDates(Database db) async {
    try {
      debugPrint('🔄 Starting journal date backfill for existing files...');
      
      // Get all files that don't have journal_date set
      final files = await db.query(
        'files',
        where: 'journal_date IS NULL OR journal_date = ""',
      );
      
      debugPrint('📋 Found ${files.length} files without journal dates');
      
      for (final fileMap in files) {
        final fileId = fileMap['id'] as String;
        final fileName = fileMap['name'] as String;
        final filePath = fileMap['file_path'] as String?;
        
        debugPrint('  📅 Processing file: $fileName');
        
        String? content;
        try {
          // Try to read file content
          if (filePath != null && filePath.isNotEmpty) {
            final file = File(filePath);
            if (await file.exists()) {
              content = await file.readAsString();
            }
          }
        } catch (e) {
          debugPrint('    ⚠️ Could not read file content: $e');
        }
        
        // Extract date using our universal date parsing service
        final extractedDate = DateParsingService.extractDate(
          filename: fileName,
          frontMatter: content != null ? _extractFrontMatter(content) : null,
          content: content ?? '',
        );
        
        if (extractedDate != null) {
          // Update the file with the extracted date
          await db.update(
            'files',
            {'journal_date': extractedDate.toIso8601String()},
            where: 'id = ?',
            whereArgs: [fileId],
          );
          debugPrint('    ✅ Set journal date: $extractedDate');
        } else {
          debugPrint('    ⚠️ No date found, keeping null');
        }
      }
      
      debugPrint('🎉 Journal date backfill completed');
    } catch (e) {
      debugPrint('🔴 Error during journal date backfill: $e');
    }
  }
  
  /// Extract YAML front matter from content for date parsing
  String? _extractFrontMatter(String content) {
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        return content.substring(3, endIndex);
      }
    }
    return null;
  }

  /// Manually trigger journal date backfill for all files (can be called from UI)
  Future<void> refreshJournalDatesForAllFiles() async {
    final db = await database;
    
    debugPrint('🔄 Manual refresh: Starting journal date update for ALL files...');
    
    // Get all files (not just ones without dates, to allow re-parsing)
    final files = await db.query('files');
    
    debugPrint('📋 Refreshing journal dates for ${files.length} files');
    
    for (final fileMap in files) {
      final fileId = fileMap['id'] as String;
      final fileName = fileMap['name'] as String;
      final filePath = fileMap['file_path'] as String?;
      
      debugPrint('  📅 Processing file: $fileName');
      
      String? content;
      try {
        // Try to read file content
        if (filePath != null && filePath.isNotEmpty) {
          final file = File(filePath);
          if (await file.exists()) {
            content = await file.readAsString();
          }
        }
      } catch (e) {
        debugPrint('    ⚠️ Could not read file content: $e');
      }
      
      // Extract date using our universal date parsing service
      final extractedDate = DateParsingService.extractDate(
        filename: fileName,
        frontMatter: content != null ? _extractFrontMatter(content) : null,
        content: content ?? '',
      );
      
      if (extractedDate != null) {
        // Update the file with the extracted date
        await db.update(
          'files',
          {'journal_date': extractedDate.toIso8601String()},
          where: 'id = ?',
          whereArgs: [fileId],
        );
        debugPrint('    ✅ Set journal date: $extractedDate');
      } else {
        // Explicitly set journal_date to null when no date is found
        await db.update(
          'files',
          {'journal_date': null},
          where: 'id = ?',
          whereArgs: [fileId],
        );
        debugPrint('    ⚠️ No date found, set journal_date to null');
      }
    }
    
    debugPrint('🎉 Manual journal date refresh completed');
  }

  /// Delete all user data - files, conversations, and clear file system
  /// Preserves the profile file but resets its content to default
  Future<void> deleteAllData() async {
    try {
      debugPrint('🗑️ Starting complete data deletion...');
      
      final db = await database;
      const profileId = 'profile_special_file';
      
      // Get all file paths before deleting from database, EXCLUDING profile file
      final files = await db.query('files');
      final filePaths = files
          .where((file) => file['id'] != profileId) // Skip profile file
          .map((file) => file['file_path'] as String?)
          .where((path) => path != null && path.isNotEmpty)
          .cast<String>()
          .toList();
      
      debugPrint('📁 Found ${filePaths.length} files to delete from filesystem (excluding profile)');
      
      // Delete physical files from filesystem (EXCLUDING profile file)
      for (final filePath in filePaths) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            debugPrint('  🗑️ Deleted file: $filePath');
          }
        } catch (e) {
          debugPrint('  ⚠️ Error deleting file $filePath: $e');
        }
      }
      
      // Don't delete the entire directory, just clean up the contents we deleted
      debugPrint('📁 Preserved journal_files directory and profile file');
      
      // Clear all database tables EXCEPT preserve profile file
      await db.transaction((txn) async {
        // Delete in order to respect foreign key constraints
        await txn.delete('conversation_messages');
        await txn.delete('conversations');
        await txn.delete('file_embeddings');
        await txn.delete('import_history');
        await txn.delete('file_insights');
        
        // Delete all files EXCEPT the profile file
        await txn.delete('files', where: 'id != ?', whereArgs: [profileId]);
        
        // Delete all FTS entries EXCEPT the profile file (if FTS5 is available)
        try {
          await txn.delete('files_fts', where: 'file_id != ?', whereArgs: [profileId]);
        } catch (e) {
          debugPrint('⚠️ FTS5 not available, skipping search index cleanup: $e');
        }
        
        await txn.delete('folders');
        
        debugPrint('🗃️ Cleared all database tables (preserved profile file)');
      });
      

      
      debugPrint('📁 Skipped recreating default folders');
      
      debugPrint('✅ Complete data deletion finished successfully');
    } catch (e) {
      debugPrint('🔴 Error during complete data deletion: $e');
      rethrow;
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

This is your AI context profile. The AI reads this file in every conversation to understand who you are. Write a few sentences about yourself, your role, what you're working on, and anything else that would help the AI have better conversations with you. Keep it personal and conversational - think of it as introducing yourself to a friend.

When you're ready, delete this instruction text and write your own introduction. The AI only sees what you write, not these instructions.
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
    
    // Update search index (if FTS5 is available)
    try {
      await db.insert('files_fts', {
        'file_id': profileId,
        'title': 'Profile',
        'content': profileContent,
      });
    } catch (e) {
      debugPrint('⚠️ FTS5 not available, skipping search index update: $e');
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
  Future<String> createFile(String name, String content, {String? folderId, DateTime? journalDate}) async {
    final db = await database;
    final documentsDir = await getApplicationDocumentsDirectory();
    

    
    // Create database entry first to get the ID
    final journalFile = JournalFile(
      name: name,
      folderId: folderId,
      filePath: '', // Will be set after creating the path
      content: content,
      wordCount: JournalFile.calculateWordCount(content),
      journalDate: journalDate,
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
    
    
    // Update search index (if FTS5 is available)
    try {
      await db.insert('files_fts', {
        'file_id': updatedJournalFile.id,
        'title': name,
        'content': content,
      });
    } catch (e) {
      debugPrint('⚠️ FTS5 not available, skipping search index update: $e');
    }
    
    
    
    
    return updatedJournalFile.id;
  }

  Future<List<JournalFile>> getFiles({String? folderId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;
    
    if (folderId == null) {
      // Get all files, let file tree handle sorting
      maps = await db.query(
        'files',
      );
    } else {
      // Get files in specific folder, let file tree handle sorting
      maps = await db.query(
        'files',
        where: 'folder_id = ?',
        whereArgs: [folderId],
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

  /// Update summary and keywords for a file (optimized context system)
  Future<void> updateFileSummary(String fileId, String? summary, String? keywords) async {
    final db = await database;
    await db.update(
      'files',
      {
        'summary': summary,
        'keywords': keywords,
      },
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }

  /// Get pinned files for AI context
  Future<List<JournalFile>> getPinnedFiles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'files',
      where: 'is_pinned = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    
    final pinnedFiles = <JournalFile>[];
    for (final map in maps) {
      final file = JournalFile.fromMap(map);
      try {
        // Read content from file system
        final fileContent = await File(file.filePath).readAsString();
        pinnedFiles.add(file.copyWith(content: fileContent));
      } catch (e) {
        debugPrint('Warning: Could not read pinned file ${file.name}: $e');
        // Add without content rather than skipping entirely
        pinnedFiles.add(file);
      }
    }
    
    return pinnedFiles;
  }

  /// Get pinned folders for AI context
  Future<List<JournalFolder>> getPinnedFolders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      where: 'is_pinned = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    
    return maps.map((map) => JournalFolder.fromMap(map)).toList();
  }

  /// Clear all summaries from all files (for regeneration)
  Future<void> clearAllSummaries() async {
    final db = await database;
    await db.update(
      'files',
      {
        'summary': null,
        'keywords': null,
      },
    );
    debugPrint('   Cleared summaries for all files');
  }

  /// Get files that need summaries (substantial content but no summary yet)
  Future<List<JournalFile>> getFilesNeedingSummary({int minWordCount = 50}) async {
    final db = await database;
    final maps = await db.query(
      'files',
      where: 'word_count >= ? AND (summary IS NULL OR summary = "")',
      whereArgs: [minWordCount],
      orderBy: 'updated_at DESC',
    );
    
    final files = <JournalFile>[];
    for (final map in maps) {
      final file = JournalFile.fromMap(map);
      // Read content from file system
      final fileContent = await File(file.filePath).readAsString();
      files.add(file.copyWith(content: fileContent));
    }
    
    return files;
  }

  /// Get all files before a specific date (for smart summary selection)
  Future<List<JournalFile>> getFilesBeforeDate(DateTime beforeDate) async {
    final db = await database;
    final maps = await db.query(
      'files',
      where: 'updated_at < ?',
      whereArgs: [beforeDate.toIso8601String()],
      orderBy: 'updated_at DESC',
    );
    
    final files = <JournalFile>[];
    for (final map in maps) {
      final file = JournalFile.fromMap(map);
      // Read content from file system
      final fileContent = await File(file.filePath).readAsString();
      files.add(file.copyWith(content: fileContent));
    }
    
    return files;
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
      
      // Delete from search index (if FTS5 is available)
      try {
        await db.delete('files_fts', where: 'file_id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('⚠️ FTS5 not available, skipping search index cleanup: $e');
      }
    }
  }

  // Search operations with fallback for systems without FTS5
  Future<List<JournalFile>> searchFiles(String query) async {
    final db = await database;
    
    try {
      // Try FTS5 search first (fastest and most accurate)
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT f.* FROM files f
        JOIN files_fts fts ON f.id = fts.file_id
        WHERE files_fts MATCH ?
        ORDER BY rank
      ''', [query]);
      
      return maps.map((map) => JournalFile.fromMap(map)).toList();
    } catch (e) {
      debugPrint('⚠️ FTS5 search failed, using fallback: $e');
      
      // Fallback to LIKE search (works on all SQLite versions)
      final List<Map<String, dynamic>> maps = await db.query(
        'files',
        where: 'name LIKE ? OR content LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'updated_at DESC',
      );
      
      return maps.map((map) => JournalFile.fromMap(map)).toList();
    }
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
    
    // Updated to check file_embeddings table instead of files.embedding column
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (beforeDate != null) {
      whereClause = 'f.updated_at < ?';
      whereArgs.add(beforeDate.toIso8601String());
    }
    
    // Query files that have entries in the file_embeddings table (chunked embeddings)
    final maps = await db.rawQuery('''
      SELECT DISTINCT f.* 
      FROM files f
      INNER JOIN file_embeddings fe ON f.id = fe.file_id
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY f.updated_at DESC
    ''', whereArgs);
    
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
        debugPrint('Error loading file content for ${file.filePath}: $e');
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



  // Import functionality methods
  Future<void> trackImport(String originalPath, String fileId) async {
    final db = await database;
    await db.insert('import_history', {
      'original_path': originalPath,
      'imported_file_id': fileId,
      'imported_at': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> isImportedFile(String fileId) async {
    final db = await database;
    final result = await db.query(
      'import_history',
      where: 'imported_file_id = ?',
      whereArgs: [fileId],
    );
    return result.isNotEmpty;
  }

  Future<void> storeChunkedEmbedding(String fileId, int chunkIndex, String content, List<double> embedding) async {
    final db = await database;
    await db.insert('file_embeddings', {
      'file_id': fileId,
      'chunk_index': chunkIndex,
      'content': content,
      'embedding': Float32List.fromList(embedding).buffer.asUint8List(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> storeInsights(String fileId, Map<String, dynamic> insights) async {
    final db = await database;
    await db.insert('file_insights', {
      'file_id': fileId,
      'word_count': insights['word_count'],
      'tags': insights['tags'] is List ? (insights['tags'] as List).join(',') : '',
      'date': insights['date'],
      'has_personal_content': insights['has_personal_content'] ? 1 : 0,
      'has_work_content': insights['has_work_content'] ? 1 : 0,
      'sentiment': insights['sentiment'],
      'original_path': insights['original_path'],
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getFileInsights(String fileId) async {
    final db = await database;
    final results = await db.query(
      'file_insights',
      where: 'file_id = ?',
      whereArgs: [fileId],
    );
    
    if (results.isNotEmpty) {
      return results.first;
    }
    
    return {};
  }

  Future<List<Map<String, dynamic>>> getFileEmbeddings(String fileId) async {
    final db = await database;
    return await db.query(
      'file_embeddings',
      where: 'file_id = ?',
      whereArgs: [fileId],
      orderBy: 'chunk_index ASC',
    );
  }

  /// Debug method: Get count of embeddings in the database
  Future<int> getEmbeddingCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM file_embeddings');
    return result.first['count'] as int;
  }

  /// Debug method: Get sample of embeddings for debugging
  Future<List<Map<String, dynamic>>> getEmbeddingSample({int limit = 5}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT fe.file_id, fe.chunk_index, f.name, LENGTH(fe.content) as content_length,
             LENGTH(fe.embedding) as embedding_size
      FROM file_embeddings fe
      JOIN files f ON fe.file_id = f.id
      ORDER BY fe.created_at DESC
      LIMIT ?
    ''', [limit]);
  }
}