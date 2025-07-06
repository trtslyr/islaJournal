import 'package:uuid/uuid.dart';

class JournalFolder {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> childFolderIds;
  final List<String> fileIds;

  JournalFolder({
    String? id,
    required this.name,
    this.parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? childFolderIds,
    List<String>? fileIds,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        childFolderIds = childFolderIds ?? [],
        fileIds = fileIds ?? [];

  JournalFolder copyWith({
    String? name,
    String? parentId,
    DateTime? updatedAt,
    List<String>? childFolderIds,
    List<String>? fileIds,
  }) {
    return JournalFolder(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      childFolderIds: childFolderIds ?? this.childFolderIds,
      fileIds: fileIds ?? this.fileIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory JournalFolder.fromMap(Map<String, dynamic> map) {
    return JournalFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'JournalFolder(id: $id, name: $name, parentId: $parentId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalFolder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}