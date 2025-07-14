import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/journal_file.dart';
import '../models/auto_tagging_models.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../services/rag_service.dart';

// AutoTaggingResult, TagSuggestion, and ThemeSuggestion classes are now imported from ../models/auto_tagging_models.dart

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
    _availableTags = await _dbService.getTags();
    _availableThemes = await _dbService.getThemes();
    debugPrint('Loaded ${_availableTags.length} tags and ${_availableThemes.length} themes');
  }

  // Main auto-tagging method
  Future<AutoTaggingResult> analyzeAndTagEntry(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      debugPrint('Starting auto-tagging analysis for entry: ${journalFile.name}');
      
      // Refresh tags and themes cache
      await _loadTagsAndThemes();
      
      // Get content analysis from AI
      final analysisResult = await _analyzeContentWithAI(journalFile.content);
      
      // Process tag suggestions
      final tagSuggestions = await _processTags(analysisResult['tags'] as List<dynamic>);
      
      // Process theme suggestions
      final themeSuggestions = await _processThemes(analysisResult['themes'] as List<dynamic>);
      
      // Calculate overall confidence
      final overallConfidence = _calculateOverallConfidence(tagSuggestions, themeSuggestions);
      
      final result = AutoTaggingResult(
        suggestedTags: tagSuggestions,
        suggestedThemes: themeSuggestions,
        overallConfidence: overallConfidence,
        analysisMetadata: {
          'analysis_version': '1.0',
          'processed_at': DateTime.now().toIso8601String(),
          'content_length': journalFile.content.length,
          'word_count': journalFile.wordCount,
          'model_used': 'llama3.2',
        },
      );
      
      debugPrint('Auto-tagging completed: ${tagSuggestions.length} tags, ${themeSuggestions.length} themes');
      return result;
    } catch (e) {
      debugPrint('Error during auto-tagging analysis: $e');
      return AutoTaggingResult(
        suggestedTags: [],
        suggestedThemes: [],
        overallConfidence: 0.0,
        analysisMetadata: {'error': e.toString()},
      );
    }
  }

  // AI content analysis
  Future<Map<String, dynamic>> _analyzeContentWithAI(String content) async {
    // Build context of available tags and themes
    final tagsContext = _availableTags.map((tag) => tag['name']).join(', ');
    final themesContext = _availableThemes.map((theme) => '${theme['name']} (${theme['category']})').join(', ');
    
    final prompt = '''
Analyze this journal entry and suggest appropriate tags and themes. Be specific and thoughtful.

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
      "reason": "why this tag applies",
      "is_existing": true
    }
  ],
  "themes": [
    {
      "name": "theme_name",
      "category": "theme_category",
      "relevance": 0.7,
      "reasoning": "why this theme is relevant",
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

Guidelines:
- Only suggest tags/themes with confidence/relevance > 0.5
- Prioritize existing tags/themes over new ones
- Consider the emotional tone, topics, activities, and context
- Be conservative - better to suggest fewer, more accurate tags
- Max 6 tags and 4 themes per entry
''';

    try {
      final response = await _aiService.generateText(
        prompt,
        maxTokens: 800,
        temperature: 0.3,
      );
      
      // Parse JSON response
      final jsonResponse = _extractJsonFromResponse(response);
      return jsonDecode(jsonResponse);
    } catch (e) {
      debugPrint('Error in AI content analysis: $e');
      return {'tags': [], 'themes': [], 'new_suggestions': {'tags': [], 'themes': []}};
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

  // Process tag suggestions
  Future<List<TagSuggestion>> _processTags(List<dynamic> aiTags) async {
    final suggestions = <TagSuggestion>[];
    
    for (final tagData in aiTags) {
      final tagName = tagData['name'] as String;
      final confidence = (tagData['confidence'] as num).toDouble();
      final reason = tagData['reason'] as String;
      final isExisting = tagData['is_existing'] as bool? ?? false;
      
      if (confidence < minTagConfidence) continue;
      
      // Find existing tag or create suggestion for new one
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
          // Tag was supposed to exist but doesn't - create new
          tagId = 'tag_${DateTime.now().millisecondsSinceEpoch}_${tagName.toLowerCase()}';
          isNewTag = true;
        }
      } else {
        tagId = 'tag_${DateTime.now().millisecondsSinceEpoch}_${tagName.toLowerCase()}';
        isNewTag = true;
      }
      
      suggestions.add(TagSuggestion(
        tagId: tagId,
        name: tagName,
        confidence: confidence,
        reason: reason,
        isExisting: !isNewTag,
      ));
    }
    
    // Sort by confidence and limit
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions.take(maxTagsPerEntry).toList();
  }

  // Process theme suggestions
  Future<List<ThemeSuggestion>> _processThemes(List<dynamic> aiThemes) async {
    final suggestions = <ThemeSuggestion>[];
    
    for (final themeData in aiThemes) {
      final themeName = themeData['name'] as String;
      final category = themeData['category'] as String;
      final relevance = (themeData['relevance'] as num).toDouble();
      final reasoning = themeData['reasoning'] as String;
      final isExisting = themeData['is_existing'] as bool? ?? false;
      
      if (relevance < minThemeRelevance) continue;
      
      // Find existing theme or create suggestion for new one
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
          // Theme was supposed to exist but doesn't - create new
          themeId = 'theme_${DateTime.now().millisecondsSinceEpoch}_${themeName.toLowerCase().replaceAll(' ', '_')}';
          isNewTheme = true;
        }
      } else {
        themeId = 'theme_${DateTime.now().millisecondsSinceEpoch}_${themeName.toLowerCase().replaceAll(' ', '_')}';
        isNewTheme = true;
      }
      
      suggestions.add(ThemeSuggestion(
        themeId: themeId,
        name: themeName,
        relevance: relevance,
        category: category,
        reasoning: reasoning,
        isExisting: !isNewTheme,
      ));
    }
    
    // Sort by relevance and limit
    suggestions.sort((a, b) => b.relevance.compareTo(a.relevance));
    return suggestions.take(maxThemesPerEntry).toList();
  }

  double _calculateOverallConfidence(List<TagSuggestion> tags, List<ThemeSuggestion> themes) {
    if (tags.isEmpty && themes.isEmpty) return 0.0;
    
    final avgTagConfidence = tags.isEmpty ? 0.0 : tags.map((t) => t.confidence).reduce((a, b) => a + b) / tags.length;
    final avgThemeRelevance = themes.isEmpty ? 0.0 : themes.map((t) => t.relevanceScore).reduce((a, b) => a + b) / themes.length;
    
    // Weight tags and themes equally
    return (avgTagConfidence + avgThemeRelevance) / 2;
  }

  // Apply auto-tagging results to a journal file
  Future<void> applyAutoTagging(String fileId, AutoTaggingResult result, {bool autoApprove = false}) async {
    try {
      // Apply tags
      for (final tagSuggestion in result.suggestedTags) {
        if (autoApprove || tagSuggestion.confidence >= 0.8) {
          // Create new tag if needed
          if (tagSuggestion.isNewTag) {
            await _dbService.createTag(tagSuggestion.tagName);
            await _loadTagsAndThemes(); // Refresh cache
          }
          
          // Add tag to file
          await _dbService.addFileTag(
            fileId,
            tagSuggestion.tagId,
            confidence: tagSuggestion.confidence,
            source: 'ai_auto_tagging',
          );
        }
      }
      
      // Apply themes
      for (final themeSuggestion in result.suggestedThemes) {
        if (autoApprove || themeSuggestion.relevanceScore >= 0.7) {
          // Create new theme if needed (would need to add createTheme method to db service)
          // For now, only apply existing themes
          if (!themeSuggestion.isNewTheme) {
            await _dbService.addFileTheme(
              fileId,
              themeSuggestion.themeId,
              themeSuggestion.relevanceScore,
              source: 'ai_auto_tagging',
            );
          }
        }
      }
      
      debugPrint('Applied auto-tagging to file $fileId');
    } catch (e) {
      debugPrint('Error applying auto-tagging: $e');
    }
  }

  // Batch process multiple files
  Future<void> batchAutoTag(List<JournalFile> files, {
    Function(int current, int total)? progressCallback,
    bool autoApprove = false,
  }) async {
    if (!_isInitialized) await initialize();
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      
      try {
        final result = await analyzeAndTagEntry(file);
        await applyAutoTagging(file.id, result, autoApprove: autoApprove);
        
        progressCallback?.call(i + 1, files.length);
        
        // Small delay to prevent overwhelming the AI service
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('Error auto-tagging file ${file.name}: $e');
      }
    }
    
    debugPrint('Batch auto-tagging completed for ${files.length} files');
  }

  // Get auto-tagging statistics
  Future<Map<String, dynamic>> getAutoTaggingStats() async {
    try {
      final aiTaggedFiles = await _dbService.database.then((db) => 
        db.rawQuery('SELECT COUNT(*) as count FROM file_tags WHERE source = ?', ['ai_auto_tagging'])
      );
      
      final aiThemedFiles = await _dbService.database.then((db) => 
        db.rawQuery('SELECT COUNT(*) as count FROM file_themes WHERE source = ?', ['ai_auto_tagging'])
      );
      
      return {
        'ai_tagged_files': aiTaggedFiles.first['count'] as int,
        'ai_themed_files': aiThemedFiles.first['count'] as int,
        'total_tags': _availableTags.length,
        'total_themes': _availableThemes.length,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  void dispose() {
    // Cleanup if needed
  }
} 