import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/journal_file.dart';
import '../models/auto_tagging_models.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../services/rag_service.dart';

class AutoTaggingService {
  static final AutoTaggingService _instance = AutoTaggingService._internal();
  factory AutoTaggingService() => _instance;
  AutoTaggingService._internal();

  final DatabaseService _dbService = DatabaseService();
  final AIService _aiService = AIService();
  final RAGService _ragService = RAGService();
  
  bool _isInitialized = false;
  List<Map<String, dynamic>> _availableTags = [];
  List<Map<String, dynamic>> _availableThemes = [];
  
  // Auto-tagging configuration
  static const double minTagConfidence = 0.6;
  static const double minThemeRelevance = 0.5;
  static const int maxTagsPerEntry = 8;
  static const int maxThemesPerEntry = 5;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _aiService.initialize();
      await _ragService.initialize();
      await _loadTagsAndThemes();
      
      _isInitialized = true;
      debugPrint('Auto-tagging Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing auto-tagging service: $e');
      throw Exception('Failed to initialize auto-tagging service: $e');
    }
  }

  Future<void> _loadTagsAndThemes() async {
    try {
      _availableTags = await _dbService.getTags();
      _availableThemes = await _dbService.getThemes();
      debugPrint('Loaded ${_availableTags.length} tags and ${_availableThemes.length} themes');
    } catch (e) {
      debugPrint('Error loading tags and themes: $e');
      _availableTags = [];
      _availableThemes = [];
    }
  }

  // Main auto-tagging method
  Future<AutoTaggingResult> analyzeAndTagEntry(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      debugPrint('Starting auto-tagging analysis for entry: ${journalFile.name}');
      
      // Skip very short entries
      if (journalFile.content.trim().length < 100) {
        debugPrint('Skipping short entry: ${journalFile.name}');
        return AutoTaggingResult(
          suggestedTags: [],
          suggestedThemes: [],
          overallConfidence: 0.0,
          analysisMetadata: {
            'skipped': true,
            'reason': 'Content too short for meaningful analysis',
            'content_length': journalFile.content.length,
          },
        );
      }
      
      // Refresh tags and themes cache
      await _loadTagsAndThemes();
      
      // Get content analysis from AI
      final analysisResult = await _analyzeContentWithAI(journalFile.content);
      
      // Process tag suggestions
      final tagSuggestions = await _processTags(analysisResult['tags'] as List<dynamic>);
      
      // Process theme suggestions
      final themeSuggestions = await _processThemes(analysisResult['themes'] as List<dynamic>);
      
      // Process new suggestions if enabled
      final newTagSuggestions = await _processNewTags(
        analysisResult['new_suggestions']?['tags'] as List<dynamic>? ?? []
      );
      final newThemeSuggestions = await _processNewThemes(
        analysisResult['new_suggestions']?['themes'] as List<dynamic>? ?? []
      );
      
      // Combine suggestions
      final allTagSuggestions = [...tagSuggestions, ...newTagSuggestions];
      final allThemeSuggestions = [...themeSuggestions, ...newThemeSuggestions];
      
      // Calculate overall confidence
      final overallConfidence = _calculateOverallConfidence(allTagSuggestions, allThemeSuggestions);
      
      final result = AutoTaggingResult(
        suggestedTags: allTagSuggestions,
        suggestedThemes: allThemeSuggestions,
        overallConfidence: overallConfidence,
        analysisMetadata: {
          'analysis_version': '1.1',
          'processed_at': DateTime.now().toIso8601String(),
          'content_length': journalFile.content.length,
          'word_count': journalFile.wordCount,
          'available_tags': _availableTags.length,
          'available_themes': _availableThemes.length,
          'ai_model_used': 'llama3.2',
        },
      );
      
      debugPrint('Auto-tagging completed: ${allTagSuggestions.length} tags, ${allThemeSuggestions.length} themes, confidence: ${overallConfidence.toStringAsFixed(2)}');
      return result;
    } catch (e) {
      debugPrint('Error during auto-tagging analysis: $e');
      return AutoTaggingResult(
        suggestedTags: [],
        suggestedThemes: [],
        overallConfidence: 0.0,
        analysisMetadata: {
          'error': e.toString(),
          'failed_at': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  // AI content analysis with improved prompt
  Future<Map<String, dynamic>> _analyzeContentWithAI(String content) async {
    // Build context of available tags and themes
    final tagsContext = _availableTags.take(20).map((tag) => tag['name']).join(', ');
    final themesContext = _availableThemes.take(15).map((theme) => '${theme['name']} (${theme['category']})').join(', ');
    
    final prompt = '''
Analyze this journal entry and suggest appropriate tags and themes. Be thoughtful and specific.

JOURNAL CONTENT:
"$content"

AVAILABLE TAGS: $tagsContext

AVAILABLE THEMES: $themesContext

Please respond with ONLY a valid JSON object in this exact format:
{
  "tags": [
    {
      "name": "tag_name",
      "confidence": 0.8,
      "reason": "specific reason why this tag applies",
      "is_existing": true
    }
  ],
  "themes": [
    {
      "name": "theme_name",
      "category": "theme_category",
      "relevance": 0.7,
      "reasoning": "detailed explanation of relevance",
      "is_existing": true
    }
  ],
  "new_suggestions": {
    "tags": [
      {
        "name": "new_tag_name",
        "confidence": 0.6,
        "reason": "why this new tag is needed"
      }
    ],
    "themes": [
      {
        "name": "new_theme_name",
        "category": "suggested_category",
        "relevance": 0.8,
        "reasoning": "why this new theme is relevant"
      }
    ]
  }
}

Analysis Guidelines:
- Only suggest tags/themes with confidence/relevance > 0.5
- Prioritize existing tags/themes over new ones
- Consider emotional tone, activities, relationships, locations, topics
- Be conservative - better fewer, more accurate suggestions
- Max 5 existing tags, 4 existing themes, 2 new tags, 1 new theme
- Focus on content that would help with future searches and insights
''';

    try {
      final response = await _aiService.generateText(
        prompt,
        maxTokens: 1000,
        temperature: 0.3,
      );
      
      // Parse JSON response
      final jsonResponse = _extractJsonFromResponse(response);
      final parsed = jsonDecode(jsonResponse);
      
      // Validate structure
      return {
        'tags': parsed['tags'] ?? [],
        'themes': parsed['themes'] ?? [],
        'new_suggestions': {
          'tags': parsed['new_suggestions']?['tags'] ?? [],
          'themes': parsed['new_suggestions']?['themes'] ?? [],
        },
      };
    } catch (e) {
      debugPrint('Error in AI content analysis: $e');
      return {
        'tags': [],
        'themes': [],
        'new_suggestions': {'tags': [], 'themes': []},
      };
    }
  }

  String _extractJsonFromResponse(String response) {
    // Find JSON object in response
    final jsonStart = response.indexOf('{');
    final jsonEnd = response.lastIndexOf('}');
    
    if (jsonStart == -1 || jsonEnd == -1 || jsonStart >= jsonEnd) {
      throw Exception('No valid JSON found in AI response');
    }
    
    return response.substring(jsonStart, jsonEnd + 1);
  }

  // Process existing tag suggestions
  Future<List<TagSuggestion>> _processTags(List<dynamic> aiTags) async {
    final suggestions = <TagSuggestion>[];
    
    for (final tagData in aiTags) {
      final tagName = tagData['name'] as String;
      final confidence = (tagData['confidence'] as num).toDouble();
      final reason = tagData['reason'] as String;
      final isExisting = tagData['is_existing'] as bool? ?? false;
      
      if (confidence < minTagConfidence) continue;
      
      // Find existing tag
      String tagId;
      bool isNewTag = false;
      
      if (isExisting) {
        final existingTag = _availableTags.firstWhere(
          (tag) => (tag['name'] as String).toLowerCase() == tagName.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        
        if (existingTag.isNotEmpty) {
          tagId = existingTag['id'] as String;
        } else {
          // Tag was supposed to exist but doesn't - skip it
          debugPrint('Expected tag "$tagName" not found, skipping');
          continue;
        }
      } else {
        tagId = 'tag_${DateTime.now().millisecondsSinceEpoch}_${tagName.toLowerCase().replaceAll(RegExp(r'[^\w]'), '_')}';
        isNewTag = true;
      }
      
      suggestions.add(TagSuggestion(
        tagId: tagId,
        tagName: tagName,
        confidence: confidence,
        reason: reason,
        isNewTag: isNewTag,
      ));
    }
    
    // Sort by confidence and limit
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions.take(maxTagsPerEntry).toList();
  }

  // Process new tag suggestions
  Future<List<TagSuggestion>> _processNewTags(List<dynamic> newTags) async {
    final suggestions = <TagSuggestion>[];
    
    for (final tagData in newTags) {
      final tagName = tagData['name'] as String;
      final confidence = (tagData['confidence'] as num).toDouble();
      final reason = tagData['reason'] as String;
      
      if (confidence < minTagConfidence) continue;
      
      // Check if tag already exists (case insensitive)
      final isDuplicate = _availableTags.any(
        (tag) => (tag['name'] as String).toLowerCase() == tagName.toLowerCase()
      );
      
      if (isDuplicate) {
        debugPrint('New tag "$tagName" already exists, skipping');
        continue;
      }
      
      final tagId = 'new_tag_${DateTime.now().millisecondsSinceEpoch}_${tagName.toLowerCase().replaceAll(RegExp(r'[^\w]'), '_')}';
      
      suggestions.add(TagSuggestion(
        tagId: tagId,
        tagName: tagName,
        confidence: confidence,
        reason: reason,
        isNewTag: true,
      ));
    }
    
    return suggestions.take(2).toList(); // Limit new tags
  }

  // Process existing theme suggestions
  Future<List<ThemeSuggestion>> _processThemes(List<dynamic> aiThemes) async {
    final suggestions = <ThemeSuggestion>[];
    
    for (final themeData in aiThemes) {
      final themeName = themeData['name'] as String;
      final category = themeData['category'] as String;
      final relevance = (themeData['relevance'] as num).toDouble();
      final reasoning = themeData['reasoning'] as String;
      final isExisting = themeData['is_existing'] as bool? ?? false;
      
      if (relevance < minThemeRelevance) continue;
      
      // Find existing theme
      String themeId;
      bool isNewTheme = false;
      
      if (isExisting) {
        final existingTheme = _availableThemes.firstWhere(
          (theme) => (theme['name'] as String).toLowerCase() == themeName.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        
        if (existingTheme.isNotEmpty) {
          themeId = existingTheme['id'] as String;
        } else {
          // Theme was supposed to exist but doesn't - skip it
          debugPrint('Expected theme "$themeName" not found, skipping');
          continue;
        }
      } else {
        themeId = 'theme_${DateTime.now().millisecondsSinceEpoch}_${themeName.toLowerCase().replaceAll(RegExp(r'[^\w]'), '_')}';
        isNewTheme = true;
      }
      
      suggestions.add(ThemeSuggestion(
        themeId: themeId,
        themeName: themeName,
        relevanceScore: relevance,
        category: category,
        reasoning: reasoning,
        isNewTheme: isNewTheme,
      ));
    }
    
    // Sort by relevance and limit
    suggestions.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return suggestions.take(maxThemesPerEntry).toList();
  }

  // Process new theme suggestions
  Future<List<ThemeSuggestion>> _processNewThemes(List<dynamic> newThemes) async {
    final suggestions = <ThemeSuggestion>[];
    
    for (final themeData in newThemes) {
      final themeName = themeData['name'] as String;
      final category = themeData['category'] as String;
      final relevance = (themeData['relevance'] as num).toDouble();
      final reasoning = themeData['reasoning'] as String;
      
      if (relevance < minThemeRelevance) continue;
      
      // Check if theme already exists (case insensitive)
      final isDuplicate = _availableThemes.any(
        (theme) => (theme['name'] as String).toLowerCase() == themeName.toLowerCase()
      );
      
      if (isDuplicate) {
        debugPrint('New theme "$themeName" already exists, skipping');
        continue;
      }
      
      final themeId = 'new_theme_${DateTime.now().millisecondsSinceEpoch}_${themeName.toLowerCase().replaceAll(RegExp(r'[^\w]'), '_')}';
      
      suggestions.add(ThemeSuggestion(
        themeId: themeId,
        themeName: themeName,
        relevanceScore: relevance,
        category: category,
        reasoning: reasoning,
        isNewTheme: true,
      ));
    }
    
    return suggestions.take(1).toList(); // Very conservative with new themes
  }

  double _calculateOverallConfidence(List<TagSuggestion> tags, List<ThemeSuggestion> themes) {
    if (tags.isEmpty && themes.isEmpty) return 0.0;
    
    final avgTagConfidence = tags.isEmpty ? 0.0 : 
        tags.map((t) => t.confidence).reduce((a, b) => a + b) / tags.length;
    final avgThemeRelevance = themes.isEmpty ? 0.0 : 
        themes.map((t) => t.relevanceScore).reduce((a, b) => a + b) / themes.length;
    
    // Weight tags slightly higher as they're generally more reliable
    if (tags.isNotEmpty && themes.isNotEmpty) {
      return (avgTagConfidence * 0.6) + (avgThemeRelevance * 0.4);
    }
    return tags.isNotEmpty ? avgTagConfidence : avgThemeRelevance;
  }

  // Apply auto-tagging results to a journal file
  Future<void> applyAutoTagging(String fileId, AutoTaggingResult result, {bool autoApprove = false}) async {
    try {
      debugPrint('Applying auto-tagging to file $fileId with ${result.suggestedTags.length} tags and ${result.suggestedThemes.length} themes');
      
      // Apply tags
      for (final tagSuggestion in result.suggestedTags) {
        if (autoApprove || tagSuggestion.shouldAutoApprove) {
          // Create new tag if needed
          if (tagSuggestion.isNewTag) {
            await _dbService.createTag(
              tagSuggestion.tagName,
              color: tagSuggestion.color,
              description: tagSuggestion.reason,
            );
            await _loadTagsAndThemes(); // Refresh cache
          }
          
          // Add tag to file
          await _dbService.addFileTag(
            fileId,
            tagSuggestion.tagId,
            confidence: tagSuggestion.confidence,
            source: 'ai_auto_tagging',
          );
          
          debugPrint('Applied tag: ${tagSuggestion.tagName} (confidence: ${tagSuggestion.confidence.toStringAsFixed(2)})');
        }
      }
      
      // Apply themes (only existing ones for now)
      for (final themeSuggestion in result.suggestedThemes) {
        if ((autoApprove || themeSuggestion.shouldAutoApprove) && !themeSuggestion.isNewTheme) {
          await _dbService.addFileTheme(
            fileId,
            themeSuggestion.themeId,
            themeSuggestion.relevanceScore,
            source: 'ai_auto_tagging',
          );
          
          debugPrint('Applied theme: ${themeSuggestion.themeName} (relevance: ${themeSuggestion.relevanceScore.toStringAsFixed(2)})');
        }
      }
      
      debugPrint('Successfully applied auto-tagging to file $fileId');
    } catch (e) {
      debugPrint('Error applying auto-tagging: $e');
      rethrow;
    }
  }

  // Batch process multiple files
  Future<void> batchAutoTag(List<JournalFile> files, {
    Function(int current, int total)? progressCallback,
    bool autoApprove = false,
  }) async {
    if (!_isInitialized) await initialize();
    
    debugPrint('Starting batch auto-tagging for ${files.length} files');
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      
      try {
        // Skip very short files
        if (file.content.trim().length < 100) {
          debugPrint('Skipping short file: ${file.name}');
          progressCallback?.call(i + 1, files.length);
          continue;
        }
        
        final result = await analyzeAndTagEntry(file);
        
        if (result.totalSuggestions > 0) {
          await applyAutoTagging(file.id, result, autoApprove: autoApprove);
        }
        
        progressCallback?.call(i + 1, files.length);
        
        // Small delay to prevent overwhelming the AI service
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('Error auto-tagging file ${file.name}: $e');
        // Continue with other files
      }
    }
    
    debugPrint('Batch auto-tagging completed for ${files.length} files');
  }

  // Get auto-tagging statistics
  Future<Map<String, dynamic>> getAutoTaggingStats() async {
    try {
      final db = await _dbService.database;
      
      final aiTaggedFiles = await db.rawQuery(
        'SELECT COUNT(DISTINCT file_id) as count FROM file_tags WHERE source = ?', 
        ['ai_auto_tagging']
      );
      
      final aiThemedFiles = await db.rawQuery(
        'SELECT COUNT(DISTINCT file_id) as count FROM file_themes WHERE source = ?', 
        ['ai_auto_tagging']
      );
      
      final totalAITags = await db.rawQuery(
        'SELECT COUNT(*) as count FROM file_tags WHERE source = ?', 
        ['ai_auto_tagging']
      );
      
      final totalAIThemes = await db.rawQuery(
        'SELECT COUNT(*) as count FROM file_themes WHERE source = ?', 
        ['ai_auto_tagging']
      );
      
      return {
        'ai_tagged_files': aiTaggedFiles.first['count'] as int,
        'ai_themed_files': aiThemedFiles.first['count'] as int,
        'total_ai_tags': totalAITags.first['count'] as int,
        'total_ai_themes': totalAIThemes.first['count'] as int,
        'total_tags': _availableTags.length,
        'total_themes': _availableThemes.length,
        'last_updated': DateTime.now().toIso8601String(),
        'service_initialized': _isInitialized,
      };
    } catch (e) {
      debugPrint('Error getting auto-tagging stats: $e');
      return {
        'error': e.toString(),
        'service_initialized': _isInitialized,
      };
    }
  }

  void dispose() {
    _isInitialized = false;
    _availableTags.clear();
    _availableThemes.clear();
  }
} 