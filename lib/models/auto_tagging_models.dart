class AutoTaggingResult {
  final List<TagSuggestion> suggestedTags;
  final List<ThemeSuggestion> suggestedThemes;
  final double overallConfidence;
  final Map<String, dynamic> analysisMetadata;
  final DateTime createdAt;

  AutoTaggingResult({
    required this.suggestedTags,
    required this.suggestedThemes,
    required this.overallConfidence,
    required this.analysisMetadata,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Helper getters
  bool get hasHighConfidenceTags => suggestedTags.any((tag) => tag.confidence >= 0.8);
  bool get hasHighRelevanceThemes => suggestedThemes.any((theme) => theme.relevanceScore >= 0.8);
  int get totalSuggestions => suggestedTags.length + suggestedThemes.length;
  
  List<TagSuggestion> get highConfidenceTags => 
      suggestedTags.where((tag) => tag.confidence >= 0.7).toList();
  
  List<ThemeSuggestion> get highRelevanceThemes => 
      suggestedThemes.where((theme) => theme.relevanceScore >= 0.7).toList();

  AutoTaggingResult copyWith({
    List<TagSuggestion>? suggestedTags,
    List<ThemeSuggestion>? suggestedThemes,
    double? overallConfidence,
    Map<String, dynamic>? analysisMetadata,
  }) {
    return AutoTaggingResult(
      suggestedTags: suggestedTags ?? this.suggestedTags,
      suggestedThemes: suggestedThemes ?? this.suggestedThemes,
      overallConfidence: overallConfidence ?? this.overallConfidence,
      analysisMetadata: analysisMetadata ?? this.analysisMetadata,
      createdAt: createdAt,
    );
  }

  @override
  String toString() {
    return 'AutoTaggingResult(tags: ${suggestedTags.length}, themes: ${suggestedThemes.length}, confidence: $overallConfidence)';
  }
}

class TagSuggestion {
  final String tagId;
  final String tagName;
  final double confidence;
  final String reason;
  final bool isNewTag;
  final String? color;

  TagSuggestion({
    required this.tagId,
    required this.tagName,
    required this.confidence,
    required this.reason,
    this.isNewTag = false,
    this.color,
  });

  // Helper getters
  String get confidenceLevel {
    if (confidence >= 0.9) return 'Very High';
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.7) return 'Good';
    if (confidence >= 0.6) return 'Medium';
    if (confidence >= 0.5) return 'Low';
    return 'Very Low';
  }

  String get confidenceColor {
    if (confidence >= 0.8) return '#4CAF50'; // Green
    if (confidence >= 0.7) return '#8BC34A'; // Light Green
    if (confidence >= 0.6) return '#FFC107'; // Amber
    if (confidence >= 0.5) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  bool get shouldAutoApprove => confidence >= 0.8 && !isNewTag;

  TagSuggestion copyWith({
    String? tagId,
    String? tagName,
    double? confidence,
    String? reason,
    bool? isNewTag,
    String? color,
  }) {
    return TagSuggestion(
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      confidence: confidence ?? this.confidence,
      reason: reason ?? this.reason,
      isNewTag: isNewTag ?? this.isNewTag,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'TagSuggestion(name: $tagName, confidence: $confidence, isNew: $isNewTag)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TagSuggestion && other.tagId == tagId;
  }

  @override
  int get hashCode => tagId.hashCode;
}

class ThemeSuggestion {
  final String themeId;
  final String themeName;
  final double relevanceScore;
  final String category;
  final String reasoning;
  final bool isNewTheme;

  ThemeSuggestion({
    required this.themeId,
    required this.themeName,
    required this.relevanceScore,
    required this.category,
    required this.reasoning,
    this.isNewTheme = false,
  });

  // Helper getters
  String get relevanceLevel {
    if (relevanceScore >= 0.9) return 'Very High';
    if (relevanceScore >= 0.8) return 'High';
    if (relevanceScore >= 0.7) return 'Good';
    if (relevanceScore >= 0.6) return 'Medium';
    if (relevanceScore >= 0.5) return 'Low';
    return 'Very Low';
  }

  String get relevanceColor {
    if (relevanceScore >= 0.8) return '#4CAF50'; // Green
    if (relevanceScore >= 0.7) return '#8BC34A'; // Light Green
    if (relevanceScore >= 0.6) return '#FFC107'; // Amber
    if (relevanceScore >= 0.5) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  bool get shouldAutoApprove => relevanceScore >= 0.7 && !isNewTheme;

  ThemeSuggestion copyWith({
    String? themeId,
    String? themeName,
    double? relevanceScore,
    String? category,
    String? reasoning,
    bool? isNewTheme,
  }) {
    return ThemeSuggestion(
      themeId: themeId ?? this.themeId,
      themeName: themeName ?? this.themeName,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      category: category ?? this.category,
      reasoning: reasoning ?? this.reasoning,
      isNewTheme: isNewTheme ?? this.isNewTheme,
    );
  }

  @override
  String toString() {
    return 'ThemeSuggestion(name: $themeName, category: $category, relevance: $relevanceScore, isNew: $isNewTheme)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeSuggestion && other.themeId == themeId;
  }

  @override
  int get hashCode => themeId.hashCode;
}

class AutoTaggingSettings {
  final bool autoTagOnSave;
  final double autoApprovalThreshold;
  final bool enableNewTagCreation;
  final bool enableNewThemeCreation;
  final List<String> excludedCategories;
  final int maxTagsPerEntry;
  final int maxThemesPerEntry;

  const AutoTaggingSettings({
    this.autoTagOnSave = false,
    this.autoApprovalThreshold = 0.8,
    this.enableNewTagCreation = true,
    this.enableNewThemeCreation = false,
    this.excludedCategories = const [],
    this.maxTagsPerEntry = 8,
    this.maxThemesPerEntry = 5,
  });

  AutoTaggingSettings copyWith({
    bool? autoTagOnSave,
    double? autoApprovalThreshold,
    bool? enableNewTagCreation,
    bool? enableNewThemeCreation,
    List<String>? excludedCategories,
    int? maxTagsPerEntry,
    int? maxThemesPerEntry,
  }) {
    return AutoTaggingSettings(
      autoTagOnSave: autoTagOnSave ?? this.autoTagOnSave,
      autoApprovalThreshold: autoApprovalThreshold ?? this.autoApprovalThreshold,
      enableNewTagCreation: enableNewTagCreation ?? this.enableNewTagCreation,
      enableNewThemeCreation: enableNewThemeCreation ?? this.enableNewThemeCreation,
      excludedCategories: excludedCategories ?? this.excludedCategories,
      maxTagsPerEntry: maxTagsPerEntry ?? this.maxTagsPerEntry,
      maxThemesPerEntry: maxThemesPerEntry ?? this.maxThemesPerEntry,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoTagOnSave': autoTagOnSave,
      'autoApprovalThreshold': autoApprovalThreshold,
      'enableNewTagCreation': enableNewTagCreation,
      'enableNewThemeCreation': enableNewThemeCreation,
      'excludedCategories': excludedCategories,
      'maxTagsPerEntry': maxTagsPerEntry,
      'maxThemesPerEntry': maxThemesPerEntry,
    };
  }

  factory AutoTaggingSettings.fromMap(Map<String, dynamic> map) {
    return AutoTaggingSettings(
      autoTagOnSave: map['autoTagOnSave'] as bool? ?? false,
      autoApprovalThreshold: map['autoApprovalThreshold'] as double? ?? 0.8,
      enableNewTagCreation: map['enableNewTagCreation'] as bool? ?? true,
      enableNewThemeCreation: map['enableNewThemeCreation'] as bool? ?? false,
      excludedCategories: List<String>.from(map['excludedCategories'] ?? []),
      maxTagsPerEntry: map['maxTagsPerEntry'] as int? ?? 8,
      maxThemesPerEntry: map['maxThemesPerEntry'] as int? ?? 5,
    );
  }

  @override
  String toString() {
    return 'AutoTaggingSettings(autoTagOnSave: $autoTagOnSave, threshold: $autoApprovalThreshold)';
  }
}