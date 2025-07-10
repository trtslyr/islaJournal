import 'package:uuid/uuid.dart';

class JournalFile {
  final String id;
  final String name;
  final String? folderId;
  final String filePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpened;
  final int wordCount;
  final String content;

  JournalFile({
    String? id,
    required this.name,
    this.folderId,
    required this.filePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastOpened,
    this.wordCount = 0,
    this.content = '',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  JournalFile copyWith({
    String? name,
    String? folderId,
    String? filePath,
    DateTime? updatedAt,
    DateTime? lastOpened,
    int? wordCount,
    String? content,
  }) {
    return JournalFile(
      id: id,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastOpened: lastOpened ?? this.lastOpened,
      wordCount: wordCount ?? this.wordCount,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'folder_id': folderId,
      'file_path': filePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_opened': lastOpened?.toIso8601String(),
      'word_count': wordCount,
    };
  }

  factory JournalFile.fromMap(Map<String, dynamic> map) {
    return JournalFile(
      id: map['id'] as String,
      name: map['name'] as String,
      folderId: map['folder_id'] as String?,
      filePath: map['file_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastOpened: map['last_opened'] != null
          ? DateTime.parse(map['last_opened'] as String)
          : null,
      wordCount: map['word_count'] as int? ?? 0,
    );
  }

  // Helper method to calculate word count
  static int calculateWordCount(String content) {
    if (content.isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  // Helper method to get file extension
  String get extension {
    return filePath.split('.').last;
  }

  // Helper method to get file size (for display purposes)
  String get displaySize {
    final bytes = content.length;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    return 'JournalFile(id: $id, name: $name, folderId: $folderId, filePath: $filePath, createdAt: $createdAt, updatedAt: $updatedAt, wordCount: $wordCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalFile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}