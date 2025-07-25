import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import '../models/journal_file.dart';
import '../models/journal_folder.dart';
import '../services/database_service.dart';
import '../services/embedding_service.dart';
import '../services/date_parsing_service.dart';
import '../services/journal_companion_service.dart';

class ImportService {
  final DatabaseService _db = DatabaseService();
  final EmbeddingService _embedding = EmbeddingService();
  
  final StreamController<ImportProgress> _progressController = StreamController<ImportProgress>.broadcast();
  Stream<ImportProgress> get progressStream => _progressController.stream;
  
  // Track current import state for detailed progress
  int _currentFileIndex = 0;
  int _totalFiles = 0;
  String _currentFileName = '';

  Future<ImportResult> importMarkdownFiles(List<File> files) async {

    final result = ImportResult();
    
    // Initialize tracking variables
    _totalFiles = files.length;
    
    // Initial progress
    _progressController.add(ImportProgress(
      current: 0,
      total: files.length,
      phase: ImportPhase.starting,
      phaseDescription: 'Preparing to import ${files.length} files...',
    ));
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = path.basename(file.path);
      
      // Update tracking variables
      _currentFileIndex = i + 1;
      _currentFileName = fileName;
      

      
      try {
        // 1. Parse markdown file
        _progressController.add(ImportProgress(
          current: i + 1,
          total: files.length,
          currentFile: fileName,
          phase: ImportPhase.parsing,
          phaseDescription: 'Parsing markdown content...',
        ));
        

        final parsed = await _parseMarkdownFile(file);
        
        
        // 2. Store in database
        _progressController.add(ImportProgress(
          current: i + 1,
          total: files.length,
          currentFile: fileName,
          phase: ImportPhase.storing,
          phaseDescription: 'Storing in database...',
        ));
        
        
        final fileId = await _storeJournalEntry(parsed);
        
        
        // 3. Index for AI
        _progressController.add(ImportProgress(
          current: i + 1,
          total: files.length,
          currentFile: fileName,
          phase: ImportPhase.embedding,
          phaseDescription: 'Generating AI embeddings...',
        ));
        
        
        await _indexForAI(fileId, parsed);
        
        
        result.filesImported++;
        
        
      } catch (e) {
        _progressController.add(ImportProgress(
          current: i + 1,
          total: files.length,
          currentFile: fileName,
          phase: ImportPhase.error,
          phaseDescription: 'Error: ${e.toString()}',
        ));
        
        result.addError(fileName, e.toString());
        
        // Brief pause on error to show the error state
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
    
    _progressController.add(ImportProgress(
      current: files.length,
      total: files.length,
      phase: ImportPhase.complete,
      phaseDescription: 'Import complete! ${result.filesImported} files imported.',
      isComplete: true,
    ));
    

    return result;
  }



  Future<ParsedEntry> _parseMarkdownFile(File file) async {
    final content = await file.readAsString();
    final parser = MarkdownParser();
    return parser.parseFile(file, content);
  }

  Future<String> _storeJournalEntry(ParsedEntry parsed) async {
    try {

      // Smart folder placement
      final folderId = await _suggestFolder(parsed);

      
      
      // Create the journal file with extracted date
      final fileId = await _db.createFile(
        parsed.title,
        parsed.content,
        folderId: folderId,
        journalDate: parsed.date,
      );
      
      
      
      // Track import history
      await _db.trackImport(parsed.originalPath, fileId);
      
      

      
      return fileId;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _suggestFolder(ParsedEntry parsed) async {
    // Place all imported files at root level - let the new sorting system handle organization
    
    return null;
  }

  Future<void> _indexForAI(String fileId, ParsedEntry parsed) async {
    try {
      // Generate embeddings for content chunks
      await _generateEmbeddings(fileId, parsed);
      
      // Update progress for insights phase
      _progressController.add(ImportProgress(
        current: _currentFileIndex,
        total: _totalFiles,
        currentFile: _currentFileName,
        phase: ImportPhase.insights,
        phaseDescription: 'Analyzing content and generating insights...',
      ));
      
      // Store insights for AI context
      await _storeInsights(fileId, parsed);
      
    } catch (e) {

      // Don't fail the import if AI indexing fails
    }
  }

  Future<void> _generateEmbeddings(String fileId, ParsedEntry parsed) async {
    // Chunk content for better embeddings
    final chunks = _chunkContent(parsed.content);
    
    
    
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      
      // Update embedding progress
      _progressController.add(ImportProgress(
        current: _currentFileIndex,
        total: _totalFiles,
        currentFile: _currentFileName,
        phase: ImportPhase.embedding,
        phaseDescription: 'Processing chunk ${i + 1}/${chunks.length}...',
        embeddingCurrent: i + 1,
        embeddingTotal: chunks.length,
      ));
      
      try {
        final embedding = await _embedding.generateEmbedding(chunk);
        await _db.storeChunkedEmbedding(fileId, i, chunk, embedding);
        
      } catch (e) {
  
      }
    }
    
    
  }

  List<String> _chunkContent(String content) {
    // Split by paragraphs, keeping chunks under 500 words
    final paragraphs = content.split('\n\n');
    final chunks = <String>[];
    String currentChunk = '';
    
    for (final paragraph in paragraphs) {
      final testChunk = currentChunk.isEmpty ? paragraph : '$currentChunk\n\n$paragraph';
      final wordCount = testChunk.split(' ').length;
      
      if (wordCount > 500 && currentChunk.isNotEmpty) {
        chunks.add(currentChunk.trim());
        currentChunk = paragraph;
      } else {
        currentChunk = testChunk;
      }
    }
    
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }
    
    return chunks;
  }

  Future<void> _storeInsights(String fileId, ParsedEntry parsed) async {
    final insights = {
      'word_count': parsed.wordCount,
      'tags': parsed.tags,
      'date': parsed.date?.toIso8601String(),
      'has_personal_content': _detectPersonalContent(parsed.content),
      'has_work_content': _detectWorkContent(parsed.content),
      'sentiment': _detectSentiment(parsed.content),
      'original_path': parsed.originalPath,
    };
    
    await _db.storeInsights(fileId, insights);
  }

  bool _detectPersonalContent(String content) {
    final personalKeywords = ['family', 'friend', 'personal', 'feeling', 'emotion', 'love', 'relationship'];
    final lowercaseContent = content.toLowerCase();
    return personalKeywords.any((keyword) => lowercaseContent.contains(keyword));
  }

  bool _detectWorkContent(String content) {
    final workKeywords = ['work', 'project', 'meeting', 'deadline', 'client', 'business', 'colleague'];
    final lowercaseContent = content.toLowerCase();
    return workKeywords.any((keyword) => lowercaseContent.contains(keyword));
  }

  String _detectSentiment(String content) {
    final positiveWords = ['happy', 'good', 'great', 'amazing', 'wonderful', 'excited', 'love', 'excellent'];
    final negativeWords = ['sad', 'bad', 'terrible', 'awful', 'worried', 'stressed', 'disappointed', 'angry'];
    
    final lowercaseContent = content.toLowerCase();
    final positiveCount = positiveWords.where((word) => lowercaseContent.contains(word)).length;
    final negativeCount = negativeWords.where((word) => lowercaseContent.contains(word)).length;
    
    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }

  void dispose() {
    _progressController.close();
  }
}

class MarkdownParser {
  ParsedEntry parseFile(File file, String content) {
    // Extract comprehensive date using our universal date parsing service
    final extractedDate = DateParsingService.extractDate(
      filename: path.basename(file.path),
      frontMatter: _extractFrontMatter(content),
      content: content,
    );
    
    return ParsedEntry(
      title: _extractTitle(content, file.path),
      content: _cleanContent(content),
      date: extractedDate,
      tags: _extractTags(content),
      metadata: _extractMetadata(content),
      originalPath: file.path,
      wordCount: _calculateWordCount(content),
    );
  }

  String _extractTitle(String content, String filePath) {
    // 1. Look for first # heading
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.startsWith('# ')) {
        return line.substring(2).trim();
      }
    }
    
    // 2. Look for YAML front matter title
    final yamlTitle = _extractYamlTitle(content);
    if (yamlTitle != null) return yamlTitle;
    
    // 3. Fallback to filename
    return path.basenameWithoutExtension(filePath);
  }

  String? _extractYamlTitle(String content) {
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        final yamlContent = content.substring(3, endIndex);
        try {
          final parsed = loadYaml(yamlContent);
          if (parsed is Map) {
            return parsed['title']?.toString();
          }
        } catch (e) {
          // Ignore YAML parsing errors
        }
      }
    }
    return null;
  }

  String? _extractFrontMatter(String content) {
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        return content.substring(3, endIndex);
      }
    }
    return null;
  }

  String _cleanContent(String content) {
    // Remove YAML front matter
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        content = content.substring(endIndex + 3);
      }
    }
    
    return content.trim();
  }



  List<String> _extractTags(String content) {
    final tags = <String>[];
    
    // Extract #hashtags
    final hashtagRegex = RegExp(r'#(\w+)');
    tags.addAll(hashtagRegex.allMatches(content)
        .map((match) => match.group(1)!)
        .toList());
    
    // Extract YAML front matter tags
    final yamlTags = _extractYamlTags(content);
    tags.addAll(yamlTags);
    
    return tags.toSet().toList(); // Remove duplicates
  }

  List<String> _extractYamlTags(String content) {
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        final yamlContent = content.substring(3, endIndex);
        try {
          final parsed = loadYaml(yamlContent);
          if (parsed is Map && parsed.containsKey('tags')) {
            final tags = parsed['tags'];
            if (tags is List) {
              return tags.map((tag) => tag.toString()).toList();
            } else if (tags is String) {
              return [tags];
            }
          }
        } catch (e) {
          // Ignore YAML parsing errors
        }
      }
    }
    return [];
  }

  Map<String, dynamic> _extractMetadata(String content) {
    final metadata = <String, dynamic>{};
    
    // Extract YAML front matter
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('---', 3);
      if (endIndex != -1) {
        final yamlContent = content.substring(3, endIndex);
        try {
          final parsed = loadYaml(yamlContent);
          if (parsed is Map) {
            metadata.addAll(parsed.cast<String, dynamic>());
          }
        } catch (e) {
          // Ignore YAML parsing errors
        }
      }
    }
    
    return metadata;
  }

  int _calculateWordCount(String content) {
    if (content.isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }
}

class ParsedEntry {
  final String title;
  final String content;
  final DateTime? date;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final String originalPath;
  final int wordCount;
  
  ParsedEntry({
    required this.title,
    required this.content,
    this.date,
    this.tags = const [],
    this.metadata = const {},
    required this.originalPath,
    required this.wordCount,
  });
}

class ImportResult {
  int filesImported = 0;
  int errors = 0;
  List<ImportError> errorMessages = [];
  
  void addError(String file, String error) {
    errors++;
    errorMessages.add(ImportError(file, error));
  }
}

class ImportError {
  final String filename;
  final String error;
  
  ImportError(this.filename, this.error);
}

class ImportProgress {
  final int current;
  final int total;
  final String? currentFile;
  final bool isComplete;
  final ImportPhase phase;
  final String phaseDescription;
  final int? embeddingCurrent;
  final int? embeddingTotal;
  
  ImportProgress({
    this.current = 0,
    this.total = 0,
    this.currentFile,
    this.isComplete = false,
    this.phase = ImportPhase.starting,
    this.phaseDescription = '',
    this.embeddingCurrent,
    this.embeddingTotal,
  });
  
  double get percentage => total > 0 ? current / total : 0.0;
  double get embeddingPercentage => 
      embeddingTotal != null && embeddingTotal! > 0 && embeddingCurrent != null
          ? embeddingCurrent! / embeddingTotal!
          : 0.0;
}

enum ImportPhase {
  starting,
  parsing,
  storing,
  embedding,
  insights,
  complete,
  error,
} 