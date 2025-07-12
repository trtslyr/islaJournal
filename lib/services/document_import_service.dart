import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import 'embedding_service.dart';

class ImportedDocument {
  final String id;
  final String originalFilename;
  final String filePath;
  final String contentType;
  final int totalPages;
  final DateTime importDate;
  final String sourceType;
  final Map<String, dynamic>? metadata;
  final int wordCount;
  final DateTime? processedAt;

  ImportedDocument({
    String? id,
    required this.originalFilename,
    required this.filePath,
    required this.contentType,
    this.totalPages = 1,
    DateTime? importDate,
    required this.sourceType,
    this.metadata,
    this.wordCount = 0,
    this.processedAt,
  })  : id = id ?? const Uuid().v4(),
        importDate = importDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_filename': originalFilename,
      'file_path': filePath,
      'content_type': contentType,
      'total_pages': totalPages,
      'import_date': importDate.toIso8601String(),
      'source_type': sourceType,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'word_count': wordCount,
      'processed_at': processedAt?.toIso8601String(),
    };
  }

  factory ImportedDocument.fromMap(Map<String, dynamic> map) {
    return ImportedDocument(
      id: map['id'] as String,
      originalFilename: map['original_filename'] as String,
      filePath: map['file_path'] as String,
      contentType: map['content_type'] as String,
      totalPages: map['total_pages'] as int? ?? 1,
      importDate: DateTime.parse(map['import_date'] as String),
      sourceType: map['source_type'] as String,
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['metadata'] as String))
          : null,
      wordCount: map['word_count'] as int? ?? 0,
      processedAt: map['processed_at'] != null
          ? DateTime.parse(map['processed_at'] as String)
          : null,
    );
  }
}

class ImportedContent {
  final String id;
  final String documentId;
  final int chunkIndex;
  final String content;
  final int? pageNumber;
  final DateTime createdAt;
  final int wordCount;

  ImportedContent({
    String? id,
    required this.documentId,
    required this.chunkIndex,
    required this.content,
    this.pageNumber,
    DateTime? createdAt,
    int? wordCount,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        wordCount = wordCount ?? _calculateWordCount(content);

  static int _calculateWordCount(String content) {
    if (content.isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'chunk_index': chunkIndex,
      'content': content,
      'page_number': pageNumber,
      'created_at': createdAt.toIso8601String(),
      'word_count': wordCount,
    };
  }

  factory ImportedContent.fromMap(Map<String, dynamic> map) {
    return ImportedContent(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      chunkIndex: map['chunk_index'] as int,
      content: map['content'] as String,
      pageNumber: map['page_number'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      wordCount: map['word_count'] as int? ?? 0,
    );
  }
}

class DocumentImportService {
  static final DocumentImportService _instance = DocumentImportService._internal();
  factory DocumentImportService() => _instance;
  DocumentImportService._internal();

  final DatabaseService _dbService = DatabaseService();
  final EmbeddingService _embeddingService = EmbeddingService();

  // Supported file types
  static const List<String> supportedExtensions = [
    'pdf', 'txt', 'md', 'docx', 'doc', 'rtf'
  ];

  // Text chunk size for processing (in characters)
  static const int chunkSize = 1000;
  static const int chunkOverlap = 200;

  Future<void> initialize() async {
    await _embeddingService.initialize();
  }

  // Import documents from file picker
  Future<List<ImportedDocument>> importDocuments({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? supportedExtensions,
        allowMultiple: allowMultiple,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final importedDocs = <ImportedDocument>[];
      
      for (final file in result.files) {
        if (file.path != null) {
          final doc = await _importSingleDocument(file.path!, file.name);
          if (doc != null) {
            importedDocs.add(doc);
          }
        }
      }

      return importedDocs;
    } catch (e) {
      print('Error importing documents: $e');
      throw Exception('Failed to import documents: $e');
    }
  }

  // Import a single document
  Future<ImportedDocument?> _importSingleDocument(String filePath, String filename) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final extension = filename.split('.').last.toLowerCase();
      if (!supportedExtensions.contains(extension)) {
        throw Exception('Unsupported file type: $extension');
      }

      // Copy file to app's documents directory
      final appDocsDir = await getApplicationDocumentsDirectory();
      final importedDir = Directory('${appDocsDir.path}/imported_documents');
      if (!await importedDir.exists()) {
        await importedDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = '${timestamp}_${filename}';
      final newFilePath = '${importedDir.path}/$newFileName';
      await file.copy(newFilePath);

      // Extract text content based on file type
      String content = '';
      int pageCount = 1;
      
      switch (extension) {
        case 'txt':
        case 'md':
          content = await _extractTextFromPlainText(newFilePath);
          break;
        case 'pdf':
          final result = await _extractTextFromPDF(newFilePath);
          content = result['content'] as String;
          pageCount = result['pages'] as int;
          break;
        case 'docx':
        case 'doc':
          content = await _extractTextFromWord(newFilePath);
          break;
        case 'rtf':
          content = await _extractTextFromRTF(newFilePath);
          break;
        default:
          throw Exception('Unsupported file type: $extension');
      }

      if (content.isEmpty) {
        throw Exception('No text content found in file');
      }

      // Create imported document record
      final importedDoc = ImportedDocument(
        originalFilename: filename,
        filePath: newFilePath,
        contentType: extension,
        totalPages: pageCount,
        sourceType: 'user_import',
        metadata: {
          'original_path': filePath,
          'file_size': await file.length(),
          'import_timestamp': timestamp,
        },
        wordCount: ImportedContent._calculateWordCount(content),
      );

      // Save to database
      await _saveImportedDocument(importedDoc);

      // Process content in chunks
      await _processDocumentContent(importedDoc, content);

      // Mark as processed
      await _markDocumentAsProcessed(importedDoc.id);

      return importedDoc;
    } catch (e) {
      print('Error importing single document: $e');
      return null;
    }
  }

  // Extract text from plain text files
  Future<String> _extractTextFromPlainText(String filePath) async {
    final file = File(filePath);
    return await file.readAsString();
  }

  // Extract text from PDF files
  Future<Map<String, dynamic>> _extractTextFromPDF(String filePath) async {
    // Note: This is a simplified implementation
    // In a real app, you'd use a PDF processing library like pdf_text
    try {
      // For now, return placeholder - you'll need to add pdf_text package
      // and implement proper PDF parsing
      return {
        'content': 'PDF content extraction not implemented yet. Please convert to text format.',
        'pages': 1,
      };
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  // Extract text from Word documents
  Future<String> _extractTextFromWord(String filePath) async {
    // Note: This is a simplified implementation
    // In a real app, you'd use a Word processing library
    try {
      // For now, return placeholder - you'll need to add docx processing
      return 'Word document content extraction not implemented yet. Please convert to text format.';
    } catch (e) {
      throw Exception('Failed to extract text from Word document: $e');
    }
  }

  // Extract text from RTF files
  Future<String> _extractTextFromRTF(String filePath) async {
    // Note: This is a simplified implementation
    // In a real app, you'd use an RTF processing library
    try {
      // For now, return placeholder
      return 'RTF content extraction not implemented yet. Please convert to text format.';
    } catch (e) {
      throw Exception('Failed to extract text from RTF: $e');
    }
  }

  // Save imported document to database
  Future<void> _saveImportedDocument(ImportedDocument doc) async {
    final db = await _dbService.database;
    await db.insert('imported_documents', doc.toMap());
  }

  // Process document content in chunks
  Future<void> _processDocumentContent(ImportedDocument doc, String content) async {
    final chunks = _chunkText(content);
    final db = await _dbService.database;
    
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      
      // Create content record
      final contentRecord = ImportedContent(
        documentId: doc.id,
        chunkIndex: i,
        content: chunk,
        pageNumber: _estimatePageNumber(i, chunks.length, doc.totalPages),
      );
      
      // Save content chunk
      await db.insert('imported_content', contentRecord.toMap());
      
      // Generate embedding for this chunk
      try {
        final embedding = await _embeddingService.generateEmbedding(
          chunk, 
          '${doc.id}_chunk_$i'
        );
        
        // Save embedding
        await _saveEmbedding(contentRecord.id, embedding, chunk);
      } catch (e) {
        print('Error generating embedding for chunk $i: $e');
      }
    }
  }

  // Split text into chunks
  List<String> _chunkText(String text) {
    final chunks = <String>[];
    int start = 0;
    
    while (start < text.length) {
      int end = start + chunkSize;
      
      // If we're not at the end, try to find a natural break
      if (end < text.length) {
        // Look for sentence endings
        final sentenceEnd = text.lastIndexOf(RegExp(r'[.!?]\s'), end);
        if (sentenceEnd > start + chunkSize ~/ 2) {
          end = sentenceEnd + 1;
        } else {
          // Look for paragraph breaks
          final paragraphEnd = text.lastIndexOf('\n\n', end);
          if (paragraphEnd > start + chunkSize ~/ 2) {
            end = paragraphEnd + 2;
          } else {
            // Look for any whitespace
            final spaceEnd = text.lastIndexOf(' ', end);
            if (spaceEnd > start + chunkSize ~/ 2) {
              end = spaceEnd + 1;
            }
          }
        }
      }
      
      chunks.add(text.substring(start, end.clamp(0, text.length)).trim());
      start = end - chunkOverlap;
    }
    
    return chunks.where((chunk) => chunk.isNotEmpty).toList();
  }

  // Estimate page number based on chunk position
  int _estimatePageNumber(int chunkIndex, int totalChunks, int totalPages) {
    if (totalPages <= 1) return 1;
    final progress = chunkIndex / totalChunks;
    return (progress * totalPages).ceil().clamp(1, totalPages);
  }

  // Save embedding to database
  Future<void> _saveEmbedding(String contentId, List<double> embedding, String text) async {
    final db = await _dbService.database;
    
    // Convert embedding to bytes for storage (same format as RAG service)
    final embeddingBytes = Float64List.fromList(embedding).buffer.asUint8List();
    
    await db.insert('file_embeddings', {
      'id': const Uuid().v4(),
      'file_id': contentId,
      'embedding': embeddingBytes,
      'embedding_version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'chunk_index': 0,
      'chunk_text': text.substring(0, text.length.clamp(0, 500)), // Store first 500 chars
    });
  }

  // Mark document as processed
  Future<void> _markDocumentAsProcessed(String documentId) async {
    final db = await _dbService.database;
    await db.update(
      'imported_documents',
      {'processed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  // Get all imported documents
  Future<List<ImportedDocument>> getImportedDocuments() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'imported_documents',
      orderBy: 'import_date DESC',
    );
    
    return maps.map((map) => ImportedDocument.fromMap(map)).toList();
  }

  // Get content chunks for a document
  Future<List<ImportedContent>> getDocumentContent(String documentId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'imported_content',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'chunk_index ASC',
    );
    
    return maps.map((map) => ImportedContent.fromMap(map)).toList();
  }

  // Search across imported content
  Future<List<ImportedContent>> searchImportedContent(String query) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'imported_content',
      where: 'content LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => ImportedContent.fromMap(map)).toList();
  }

  // Delete an imported document and all its content
  Future<void> deleteImportedDocument(String documentId) async {
    final db = await _dbService.database;
    
    // Get document info first
    final docMaps = await db.query(
      'imported_documents',
      where: 'id = ?',
      whereArgs: [documentId],
    );
    
    if (docMaps.isNotEmpty) {
      final doc = ImportedDocument.fromMap(docMaps.first);
      
      // Delete file from disk
      final file = File(doc.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Delete from database (cascading deletes will handle related records)
      await db.delete(
        'imported_documents',
        where: 'id = ?',
        whereArgs: [documentId],
      );
    }
  }

  // Get import statistics
  Future<Map<String, dynamic>> getImportStats() async {
    final db = await _dbService.database;
    
    final docCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM imported_documents');
    final contentCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM imported_content');
    final totalWordsResult = await db.rawQuery('SELECT SUM(word_count) as total FROM imported_documents');
    
    return {
      'totalDocuments': docCountResult.first['count'] as int,
      'totalChunks': contentCountResult.first['count'] as int,
      'totalWords': totalWordsResult.first['total'] as int? ?? 0,
    };
  }
} 