class ContextSettings {
  final List<String> selectedFileIds; // Files selected for full context inclusion
  final int maxTokens; // Token budget for all context
  
  const ContextSettings({
    this.selectedFileIds = const [],
    this.maxTokens = 4000, // Balanced default: 2200 tokens for optional context
  });
  
  // Default empty settings
  static const ContextSettings empty = ContextSettings();
  
  ContextSettings copyWith({
    List<String>? selectedFileIds,
    int? maxTokens,
  }) {
    return ContextSettings(
      selectedFileIds: selectedFileIds ?? this.selectedFileIds,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedFileIds': selectedFileIds,
      'maxTokens': maxTokens,
    };
  }

  static ContextSettings fromJson(Map<String, dynamic> json) {
    return ContextSettings(
      selectedFileIds: List<String>.from(json['selectedFileIds'] ?? []),
      maxTokens: json['maxTokens'] ?? 4000,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContextSettings &&
        other.selectedFileIds.length == selectedFileIds.length &&
        other.selectedFileIds.every((id) => selectedFileIds.contains(id)) &&
        other.maxTokens == maxTokens;
  }

  @override
  int get hashCode {
    return Object.hash(selectedFileIds, maxTokens);
  }
} 