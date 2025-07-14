class TagSuggestion {
  final String name;
  final double confidence;
  final String reason;
  final bool isExisting;
  final String? tagId;

  TagSuggestion({
    required this.name,
    required this.confidence,
    required this.reason,
    required this.isExisting,
    this.tagId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'confidence': confidence,
      'reason': reason,
      'isExisting': isExisting,
      'tagId': tagId,
    };
  }

  factory TagSuggestion.fromMap(Map<String, dynamic> map) {
    return TagSuggestion(
      name: map['name'] as String,
      confidence: map['confidence'] as double,
      reason: map['reason'] as String,
      isExisting: map['isExisting'] as bool,
      tagId: map['tagId'] as String?,
    );
  }
}

class ThemeSuggestion {
  final String name;
  final String category;
  final double relevance;
  final String reasoning;
  final bool isExisting;
  final String? themeId;

  ThemeSuggestion({
    required this.name,
    required this.category,
    required this.relevance,
    required this.reasoning,
    required this.isExisting,
    this.themeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'relevance': relevance,
      'reasoning': reasoning,
      'isExisting': isExisting,
      'themeId': themeId,
    };
  }

  factory ThemeSuggestion.fromMap(Map<String, dynamic> map) {
    return ThemeSuggestion(
      name: map['name'] as String,
      category: map['category'] as String,
      relevance: map['relevance'] as double,
      reasoning: map['reasoning'] as String,
      isExisting: map['isExisting'] as bool,
      themeId: map['themeId'] as String?,
    );
  }
}

class AutoTaggingResult {
  final List<TagSuggestion> suggestedTags;
  final List<ThemeSuggestion> suggestedThemes;
  final double overallConfidence;
  final Map<String, dynamic> analysisMetadata;

  AutoTaggingResult({
    required this.suggestedTags,
    required this.suggestedThemes,
    required this.overallConfidence,
    required this.analysisMetadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'suggestedTags': suggestedTags.map((tag) => tag.toMap()).toList(),
      'suggestedThemes': suggestedThemes.map((theme) => theme.toMap()).toList(),
      'overallConfidence': overallConfidence,
      'analysisMetadata': analysisMetadata,
    };
  }

  factory AutoTaggingResult.fromMap(Map<String, dynamic> map) {
    return AutoTaggingResult(
      suggestedTags: (map['suggestedTags'] as List)
          .map((item) => TagSuggestion.fromMap(item))
          .toList(),
      suggestedThemes: (map['suggestedThemes'] as List)
          .map((item) => ThemeSuggestion.fromMap(item))
          .toList(),
      overallConfidence: map['overallConfidence'] as double,
      analysisMetadata: Map<String, dynamic>.from(map['analysisMetadata']),
    );
  }
}