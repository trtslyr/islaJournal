class WritingPrompt {
  final String id;
  final String prompt;
  final String category;
  final String inspiration;
  final DateTime createdAt;
  final double relevanceScore;
  final Map<String, dynamic> context;

  WritingPrompt({
    required this.id,
    required this.prompt,
    required this.category,
    required this.inspiration,
    required this.createdAt,
    required this.relevanceScore,
    required this.context,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prompt': prompt,
      'category': category,
      'inspiration': inspiration,
      'createdAt': createdAt.toIso8601String(),
      'relevanceScore': relevanceScore,
      'context': context,
    };
  }

  factory WritingPrompt.fromMap(Map<String, dynamic> map) {
    return WritingPrompt(
      id: map['id'] as String,
      prompt: map['prompt'] as String,
      category: map['category'] as String,
      inspiration: map['inspiration'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      relevanceScore: map['relevanceScore'] as double,
      context: Map<String, dynamic>.from(map['context']),
    );
  }
}

enum PromptCategory {
  reflection('Reflection'),
  growth('Personal Growth'),
  creativity('Creative'),
  emotions('Emotional'),
  goals('Goals & Dreams'),
  relationships('Relationships'),
  memories('Memories'),
  future('Future Planning'),
  gratitude('Gratitude'),
  challenges('Challenges');

  const PromptCategory(this.displayName);
  final String displayName;
}