class ValidationService {
  static const int maxNameLength = 255;
  static const int minNameLength = 1;
  
  // Invalid characters for file/folder names across platforms
  static const List<String> invalidCharacters = [
    '/', '\\', ':', '*', '?', '"', '<', '>', '|', '\n', '\r', '\t'
  ];
  
  // Reserved names that shouldn't be used
  static const List<String> reservedNames = [
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
  ];

  /// Validates a file or folder name
  /// Returns null if valid, or error message if invalid
  static String? validateName(String name, {bool isFolder = false}) {
    // Trim whitespace
    name = name.trim();
    
    // Check empty or too short
    if (name.isEmpty) {
      return isFolder ? 'Folder name cannot be empty' : 'File name cannot be empty';
    }
    
    // Check minimum length
    if (name.length < minNameLength) {
      return isFolder 
          ? 'Folder name must be at least $minNameLength character'
          : 'File name must be at least $minNameLength character';
    }
    
    // Check maximum length
    if (name.length > maxNameLength) {
      return isFolder 
          ? 'Folder name cannot exceed $maxNameLength characters'
          : 'File name cannot exceed $maxNameLength characters';
    }
    
    // Check for invalid characters
    for (final char in invalidCharacters) {
      if (name.contains(char)) {
        return isFolder 
            ? 'Folder name cannot contain: ${invalidCharacters.join(' ')}'
            : 'File name cannot contain: ${invalidCharacters.join(' ')}';
      }
    }
    
    // Check for reserved names (case-insensitive)
    if (reservedNames.contains(name.toUpperCase())) {
      return isFolder 
          ? '"$name" is a reserved name and cannot be used for folders'
          : '"$name" is a reserved name and cannot be used for files';
    }
    
    // Check for names that start or end with spaces or dots
    if (name.startsWith(' ') || name.endsWith(' ')) {
      return isFolder 
          ? 'Folder name cannot start or end with spaces'
          : 'File name cannot start or end with spaces';
    }
    
    if (name.startsWith('.') || name.endsWith('.')) {
      return isFolder 
          ? 'Folder name cannot start or end with dots'
          : 'File name cannot start or end with dots';
    }
    
    return null; // Valid name
  }
  
  /// Checks if a file name already exists in the given folder
  static bool isFileNameDuplicate(String name, List<String> existingNames) {
    return existingNames.any((existing) => 
        existing.toLowerCase() == name.toLowerCase());
  }
  
  /// Checks if a folder name already exists in the given parent folder
  static bool isFolderNameDuplicate(String name, List<String> existingNames) {
    return existingNames.any((existing) => 
        existing.toLowerCase() == name.toLowerCase());
  }
  
  /// Generates a unique name by appending a number if duplicate exists
  static String generateUniqueName(String baseName, List<String> existingNames) {
    if (!isFileNameDuplicate(baseName, existingNames)) {
      return baseName;
    }
    
    int counter = 1;
    String newName;
    do {
      newName = '$baseName ($counter)';
      counter++;
    } while (isFileNameDuplicate(newName, existingNames) && counter < 1000);
    
    return newName;
  }
  
  /// Sanitizes a name by removing invalid characters
  static String sanitizeName(String name) {
    String sanitized = name.trim();
    
    // Replace invalid characters with underscores
    for (final char in invalidCharacters) {
      sanitized = sanitized.replaceAll(char, '_');
    }
    
    // Remove multiple consecutive underscores
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    
    // Remove leading/trailing underscores
    sanitized = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
    
    // Ensure it's not empty after sanitization
    if (sanitized.isEmpty) {
      sanitized = 'untitled';
    }
    
    // Check if it's a reserved name and modify if needed
    if (reservedNames.contains(sanitized.toUpperCase())) {
      sanitized = '${sanitized}_file';
    }
    
    return sanitized;
  }
  
  /// Validates content length for saving
  static String? validateContentLength(String content) {
    const maxContentLength = 10 * 1024 * 1024; // 10MB limit
    
    if (content.length > maxContentLength) {
      return 'File content cannot exceed ${(maxContentLength / (1024 * 1024)).round()}MB';
    }
    
    return null;
  }
} 