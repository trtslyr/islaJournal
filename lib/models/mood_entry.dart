import 'dart:convert';

class MoodEntry {
  final String id;
  final String fileId;
  final DateTime date;
  final double valence; // -1 (negative) to 1 (positive)
  final double arousal; // 0 (calm) to 1 (excited)
  final List<String> emotions;
  final String summary;
  final double confidence;
  final DateTime createdAt;

  MoodEntry({
    required this.id,
    required this.fileId,
    required this.date,
    required this.valence,
    required this.arousal,
    required this.emotions,
    required this.summary,
    required this.confidence,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'valence': valence,
      'arousal': arousal,
      'emotions': jsonEncode(emotions),
      'confidence': confidence,
      'analysis_version': 1,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'metadata': jsonEncode({
        'summary': summary,
        'date': date.toIso8601String(),
      }),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    final metadata = map['metadata'] != null 
        ? jsonDecode(map['metadata'] as String) as Map<String, dynamic>
        : <String, dynamic>{};

    return MoodEntry(
      id: map['id'] as String,
      fileId: map['file_id'] as String,
      date: DateTime.parse(metadata['date'] ?? map['created_at']),
      valence: map['valence'] as double,
      arousal: map['arousal'] as double,
      emotions: List<String>.from(jsonDecode(map['emotions'] as String)),
      summary: metadata['summary'] ?? '',
      confidence: map['confidence'] as double,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  MoodEntry copyWith({
    String? id,
    String? fileId,
    DateTime? date,
    double? valence,
    double? arousal,
    List<String>? emotions,
    String? summary,
    double? confidence,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      date: date ?? this.date,
      valence: valence ?? this.valence,
      arousal: arousal ?? this.arousal,
      emotions: emotions ?? this.emotions,
      summary: summary ?? this.summary,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt,
    );
  }

  // Helper methods
  String get primaryEmotion => emotions.isNotEmpty ? emotions.first : 'neutral';
  
  String get valenceMood {
    if (valence > 0.3) return 'positive';
    if (valence < -0.3) return 'negative';
    return 'neutral';
  }
  
  String get arousalLevel {
    if (arousal > 0.7) return 'high';
    if (arousal > 0.3) return 'medium';
    return 'low';
  }
  
  String get confidenceLevel {
    if (confidence > 0.8) return 'high';
    if (confidence > 0.6) return 'medium';
    return 'low';
  }

  @override
  String toString() {
    return 'MoodEntry(id: $id, valence: $valence, arousal: $arousal, emotions: $emotions, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoodEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class MoodPattern {
  final DateTime startDate;
  final DateTime endDate;
  final double averageValence;
  final double averageArousal;
  final Map<String, int> emotionFrequency;
  final List<MoodEntry> entries;
  final String trend; // 'improving', 'declining', 'stable'
  final Map<String, double> metrics;

  MoodPattern({
    required this.startDate,
    required this.endDate,
    required this.averageValence,
    required this.averageArousal,
    required this.emotionFrequency,
    required this.entries,
    required this.trend,
    Map<String, double>? metrics,
  }) : metrics = metrics ?? {};

  // Helper getters
  String get dominantEmotion {
    if (emotionFrequency.isEmpty) return 'neutral';
    return emotionFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  List<String> get topEmotions {
    final sorted = emotionFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  double get variability {
    if (entries.length < 2) return 0.0;
    
    final valences = entries.map((e) => e.valence).toList();
    final mean = averageValence;
    final variance = valences.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / valences.length;
    return variance;
  }

  String get stabilityDescription {
    final v = variability;
    if (v < 0.1) return 'very stable';
    if (v < 0.3) return 'stable';
    if (v < 0.6) return 'somewhat variable';
    return 'highly variable';
  }

  factory MoodPattern.empty({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return MoodPattern(
      startDate: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      endDate: endDate ?? DateTime.now(),
      averageValence: 0.0,
      averageArousal: 0.0,
      emotionFrequency: {},
      entries: [],
      trend: 'stable',
    );
  }

  @override
  String toString() {
    return 'MoodPattern(entries: ${entries.length}, trend: $trend, avgValence: $averageValence, avgArousal: $averageArousal)';
  }
}