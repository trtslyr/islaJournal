enum ContextMode {
  general,
  timeframe,
  custom,
}

enum TimeframeOption {
  last7Days,
  last30Days,
  last90Days,
  lastYear,
  allTime,
}

class ContextSettings {
  final ContextMode mode;
  final TimeframeOption? timeframe;
  final List<String> customFileIds;
  final int maxTokens;
  
  const ContextSettings({
    this.mode = ContextMode.general,
    this.timeframe,
    this.customFileIds = const [],
    this.maxTokens = 20000, // Default context token limit
  });
  
  // Default general context settings
  static const ContextSettings general = ContextSettings(
    mode: ContextMode.general,
  );
  
  // Default timeframe settings
  static const ContextSettings timeframe30Days = ContextSettings(
    mode: ContextMode.timeframe,
    timeframe: TimeframeOption.last30Days,
  );
  
  // Empty custom settings
  static const ContextSettings customEmpty = ContextSettings(
    mode: ContextMode.custom,
    customFileIds: [],
  );
  
  ContextSettings copyWith({
    ContextMode? mode,
    TimeframeOption? timeframe,
    List<String>? customFileIds,
    int? maxTokens,
  }) {
    return ContextSettings(
      mode: mode ?? this.mode,
      timeframe: timeframe ?? this.timeframe,
      customFileIds: customFileIds ?? this.customFileIds,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }
  
  // Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'timeframe': timeframe?.name,
      'customFileIds': customFileIds,
      'maxTokens': maxTokens,
    };
  }
  
  // Create from JSON from database
  factory ContextSettings.fromJson(Map<String, dynamic> json) {
    return ContextSettings(
      mode: ContextMode.values.byName(json['mode'] as String),
      timeframe: json['timeframe'] != null 
          ? TimeframeOption.values.byName(json['timeframe'] as String)
          : null,
      customFileIds: List<String>.from(json['customFileIds'] as List? ?? []),
      maxTokens: json['maxTokens'] as int? ?? 20000,
    );
  }
  
  // Get human-readable description
  String get description {
    switch (mode) {
      case ContextMode.general:
        return 'General context (recent + relevant + long-term)';
      case ContextMode.timeframe:
        return 'Timeframe: ${timeframe?.displayName ?? 'Not set'}';
      case ContextMode.custom:
        return 'Custom: ${customFileIds.length} files selected';
    }
  }
  
  // Get timeframe duration in days
  int? get timeframeDays {
    switch (timeframe) {
      case TimeframeOption.last7Days:
        return 7;
      case TimeframeOption.last30Days:
        return 30;
      case TimeframeOption.last90Days:
        return 90;
      case TimeframeOption.lastYear:
        return 365;
      case TimeframeOption.allTime:
        return null; // No limit
      case null:
        return null;
    }
  }
}

extension TimeframeOptionExtension on TimeframeOption {
  String get displayName {
    switch (this) {
      case TimeframeOption.last7Days:
        return 'Last 7 days';
      case TimeframeOption.last30Days:
        return 'Last 30 days';
      case TimeframeOption.last90Days:
        return 'Last 90 days';
      case TimeframeOption.lastYear:
        return 'Last year';
      case TimeframeOption.allTime:
        return 'All time';
    }
  }
} 