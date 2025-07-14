class MoodEntry {
  final String id;
  final String fileId;
  final DateTime date;
  final double valence; // -1.0 (negative) to 1.0 (positive)
  final double arousal; // 0.0 (calm) to 1.0 (excited)
  final List<String> emotions;
  final String summary;
  final double confidence; // 0.0 to 1.0
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

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
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'date': date.toIso8601String(),
      'valence': valence,
      'arousal': arousal,
      'emotions': emotions.join(','),
      'summary': summary,
      'confidence': confidence,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata != null ? metadata.toString() : null,
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as String,
      fileId: map['file_id'] as String,
      date: DateTime.parse(map['date'] as String),
      valence: map['valence'] as double,
      arousal: map['arousal'] as double,
      emotions: (map['emotions'] as String).split(',').where((e) => e.isNotEmpty).toList(),
      summary: map['summary'] as String,
      confidence: map['confidence'] as double,
      createdAt: DateTime.parse(map['created_at'] as String),
      metadata: map['metadata'] != null ? {'raw': map['metadata']} : null,
    );
  }

  // Helper getters
  String get primaryEmotion => emotions.isNotEmpty ? emotions.first : 'neutral';
  
  String get moodDescription {
    if (valence > 0.5) return 'positive';
    if (valence < -0.5) return 'negative';
    return 'neutral';
  }
  
  String get energyLevel {
    if (arousal > 0.7) return 'high';
    if (arousal > 0.3) return 'moderate';
    return 'low';
  }
}