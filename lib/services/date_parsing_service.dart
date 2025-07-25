import 'dart:core';

/// Universal date parsing service that can detect dates in any format
/// from filenames, YAML front matter, and content
class DateParsingService {
  
  /// Extract the most relevant date from a file during import
  static DateTime? extractDate({
    required String filename,
    String? frontMatter,
    required String content,
  }) {
    // Priority order for date extraction:
    // 1. YAML front matter date field
    // 2. Content header dates (# Date:, ## Date, etc.)
    // 3. Filename dates
    // 4. First date found in content
    
    DateTime? date;
    
    // 1. Check YAML front matter first (highest priority)
    if (frontMatter != null) {
      date = _extractFromYaml(frontMatter);
      if (date != null && _isReasonableJournalDate(date)) {
        return date;
      }
    }
    
    // 2. Check content headers (Date:, ## Date, etc.)
    date = _extractFromContentHeaders(content);
    if (date != null && _isReasonableJournalDate(date)) {
      return date;
    }
    
    // 3. Check filename
    date = _extractFromFilename(filename);
    if (date != null && _isReasonableJournalDate(date)) {
      return date;
    }
    
    // 4. Check general content (lowest priority)
    date = _extractFromContent(content);
    if (date != null && _isReasonableJournalDate(date)) {
      return date;
    }
    
    return null; // Return null instead of current date fallback
  }
  
  /// Validate that a date is reasonable for a journal entry
  /// Rejects dates that are too far in the future or too old
  static bool _isReasonableJournalDate(DateTime date) {
    final now = DateTime.now();
    final oneYearFromNow = now.add(const Duration(days: 365));
    final tenYearsAgo = now.subtract(const Duration(days: 365 * 10));
    
    // Journal entries should be within reasonable bounds
    if (date.isAfter(oneYearFromNow)) {
      return false;
    }
    
    if (date.isBefore(tenYearsAgo)) {
      return false;
    }
    
    return true;
  }
  
  /// Extract date from YAML front matter
  static DateTime? _extractFromYaml(String frontMatter) {
    final lines = frontMatter.split('\n');
    
    for (final line in lines) {
      final trimmed = line.trim().toLowerCase();
      
      // Look for date fields: date:, created:, published:, etc.
      if (trimmed.startsWith('date:') || 
          trimmed.startsWith('created:') || 
          trimmed.startsWith('published:') ||
          trimmed.startsWith('written:') ||
          trimmed.startsWith('timestamp:')) {
        
        final dateStr = line.split(':').skip(1).join(':').trim();
        final parsed = _parseAnyDateFormat(dateStr);
        if (parsed != null) return parsed;
      }
    }
    
    return null;
  }
  
  /// Extract date from content - looks for actual date patterns anywhere
  static DateTime? _extractFromContentHeaders(String content) {
    // Look for actual date patterns in the entire content using regex
    final dateRegexes = [
      // Explicit date patterns (most reliable)
      RegExp(r'\b\d{4}[-/.]\d{1,2}[-/.]\d{1,2}\b'),           // 2024-12-29, 2024/12/29, 2024.12.29
      RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{4}\b'),           // 12/29/2024, 12-29-2024, 12.29.2024
      RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2}\b'),           // 12/29/24, 12-29-24, 12.29.24
      
      // Text-based dates
      RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},?\s+\d{4}\b', caseSensitive: false),  // Dec 29, 2024
      RegExp(r'\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}\b', caseSensitive: false),     // 29 Dec 2024
      RegExp(r'\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}\b', caseSensitive: false), // December 29, 2024
    ];
    
    for (final regex in dateRegexes) {
      final match = regex.firstMatch(content);
      if (match != null) {
        final dateStr = match.group(0)!;
        final parsed = _parseAnyDateFormat(dateStr);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    
    return null;
  }
  
  /// Extract date from filename
  static DateTime? _extractFromFilename(String filename) {
    // Remove file extension
    final nameWithoutExt = filename.replaceFirst(RegExp(r'\.[^.]*$'), '');
    
    return _parseAnyDateFormat(nameWithoutExt);
  }
  
  /// Extract first date found in content using simple regex patterns
  static DateTime? _extractFromContent(String content) {
    // Use the same simple approach as content headers
    final dateRegexes = [
      RegExp(r'\b\d{4}[-/.]\d{1,2}[-/.]\d{1,2}\b'),           // 2024-12-29, 2024/12/29, 2024.12.29
      RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{4}\b'),           // 12/29/2024, 12-29-2024, 12.29.2024
      RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2}\b'),           // 12/29/24, 12-29-24, 12.29.24
      RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2},?\s+\d{4}\b', caseSensitive: false),
      RegExp(r'\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}\b', caseSensitive: false),
    ];
    
    for (final regex in dateRegexes) {
      final match = regex.firstMatch(content);
      if (match != null) {
        final dateStr = match.group(0)!;
        final parsed = _parseAnyDateFormat(dateStr);
        if (parsed != null) return parsed;
      }
    }
    
    return null;
  }
  
  /// Parse any date format into DateTime
  static DateTime? _parseAnyDateFormat(String dateStr) {
    if (dateStr.isEmpty) return null;
    
    // Clean the string
    String cleaned = dateStr.trim()
        .replaceAll(RegExp(r'[,]'), ' ')  // Remove commas
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize spaces
    
    // Try all possible date formats
    final formats = _getAllDateFormats();
    
    for (final format in formats) {
      try {
        final parsed = format(cleaned);
        if (parsed != null) {
          // Validate reasonable date range (1900-2100)
          if (parsed.year >= 1900 && parsed.year <= 2100) {
            return parsed;
          }
        }
      } catch (e) {
        // Continue to next format
      }
    }
    
    return null;
  }
  
  /// Get all possible date parsing functions - ONLY actual date formats
  static List<DateTime? Function(String)> _getAllDateFormats() {
    return [
      _parseISODate,                    // 2024-01-15, 2024/01/15, 2024.01.15
      _parseInternationalDate,          // Handles both US and European ambiguous dates
      _parseUSDateExplicit,             // Explicit US format with context clues
      _parseEuropeanDateExplicit,       // Explicit European format with context clues
      _parseCompactDate,                // 20240115
      _parseTextualDate,                // January 15, 2024
      _parseEnhancedTextualDate,        // January 15th, 2024
      _parseShortTextualDate,           // Jan 15 2024, 15 Jan 2024, 10 Dec 2024
      _parseOrdinalDate,                // 15th January 2024, 1st Jan
      _parseAlternativeFormats,         // dd.mm.yyyy, dd-mm-yyyy, yyyy.mm.dd, etc.
    ];
  }
  
  /// Parse ISO format dates (2024-01-15, 2024/01/15, 2024.01.15)
  static DateTime? _parseISODate(String dateStr) {
    final patterns = [
      RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        
        if (_isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }
      }
    }
    
    return null;
  }
  
  /// Parse international dates with intelligent disambiguation
  /// Handles both mm/dd/yyyy and dd/mm/yyyy by using context clues
  static DateTime? _parseInternationalDate(String dateStr) {
    final patterns = [
      RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$'),
      RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})$'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        final first = int.parse(match.group(1)!);
        final second = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        
        // Handle 2-digit years
        if (year < 100) {
          year += year < 50 ? 2000 : 1900;
        }
        
        // Smart disambiguation: try both interpretations and return the most likely
        final possibilities = <DateTime>[];
        
        // Try US format (mm/dd/yyyy)
        if (_isValidDate(year, first, second)) {
          possibilities.add(DateTime(year, first, second));
        }
        
        // Try European format (dd/mm/yyyy)
        if (_isValidDate(year, second, first)) {
          possibilities.add(DateTime(year, second, first));
        }
        
        // If only one interpretation is valid, use it
        if (possibilities.length == 1) {
          return possibilities.first;
        }
        
        // If both are valid, use additional heuristics
        if (possibilities.length == 2) {
          // Prefer European format if day > 12 (clearly not a month)
          if (first > 12) {
            return DateTime(year, second, first); // European: dd/mm/yyyy
          }
          if (second > 12) {
            return DateTime(year, first, second); // US: mm/dd/yyyy
          }
          
          // If still ambiguous, prefer US format (more common in many contexts)
          return DateTime(year, first, second); // US: mm/dd/yyyy
        }
      }
    }
    
    return null;
  }
  
  /// Parse explicit US format dates with clear indicators
  static DateTime? _parseUSDateExplicit(String dateStr) {
    // This is for when we have clear US format indicators
    return _parseUSDate(dateStr);
  }
  
  /// Parse explicit European format dates with clear indicators  
  static DateTime? _parseEuropeanDateExplicit(String dateStr) {
    // This is for when we have clear European format indicators
    return _parseEuropeanDate(dateStr);
  }
  
  /// Parse US format dates (01/15/2024, 1/15/24)
  static DateTime? _parseUSDate(String dateStr) {
    final patterns = [
      RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$'),
      RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{2})$'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        final month = int.parse(match.group(1)!);
        final day = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        
        // Handle 2-digit years
        if (year < 100) {
          year += year < 50 ? 2000 : 1900;
        }
        
        if (_isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }
      }
    }
    
    return null;
  }
  
  /// Parse European format dates (15/01/2024, 15.01.2024)
  static DateTime? _parseEuropeanDate(String dateStr) {
    final patterns = [
      RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{4})$'),
      RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{2})$'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        
        // Handle 2-digit years
        if (year < 100) {
          year += year < 50 ? 2000 : 1900;
        }
        
        if (_isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }
      }
    }
    
    return null;
  }
  
  /// Parse alternative international formats
  static DateTime? _parseAlternativeFormats(String dateStr) {
    final patterns = [
      // yyyy.mm.dd format (common in some Asian countries)
      RegExp(r'^(\d{4})\.(\d{1,2})\.(\d{1,2})$'),
      // dd-mm-yyyy format (European with dashes)
      RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$'),
      // yyyy-mm-dd with different separators
      RegExp(r'^(\d{4})\.(\d{1,2})\.(\d{1,2})$'),
      // dd.mm.yyyy format (European with dots)
      RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$'),
      // mm.dd.yyyy format (US with dots)
      RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$'),
    ];
    
    final patternTypes = [
      'iso',        // yyyy.mm.dd
      'european',   // dd-mm-yyyy
      'iso',        // yyyy.mm.dd (duplicate for dots)
      'european',   // dd.mm.yyyy
      'us',         // mm.dd.yyyy
    ];
    
    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final type = patternTypes[i];
      final match = pattern.firstMatch(dateStr);
      
      if (match != null) {
        int year, month, day;
        
        if (type == 'iso') {
          year = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          day = int.parse(match.group(3)!);
        } else if (type == 'european') {
          day = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          year = int.parse(match.group(3)!);
        } else { // us
          month = int.parse(match.group(1)!);
          day = int.parse(match.group(2)!);
          year = int.parse(match.group(3)!);
        }
        
        if (_isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }
      }
    }
    
    return null;
  }
  
  /// Parse textual dates (January 15, 2024, 15 January 2024)
  static DateTime? _parseTextualDate(String dateStr) {
    final months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'jun': 6, 'jul': 7, 'aug': 8,
      'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      // Additional international abbreviations
      'mai': 5, 'mai.': 5, // May in some languages
      'dez': 12, 'dez.': 12, // Dec in German/Portuguese
    };
    
    final lower = dateStr.toLowerCase();
    
    // Month Day, Year (January 15, 2024)
    var pattern = RegExp(r'^(\w+)\s+(\d{1,2}),?\s+(\d{2,4})$');
    var match = pattern.firstMatch(lower);
    if (match != null) {
      final monthName = match.group(1)!;
      final day = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);
      
      if (year < 100) year += year < 50 ? 2000 : 1900;
      
      final month = months[monthName];
      if (month != null && _isValidDate(year, month, day)) {
        return DateTime(year, month, day);
      }
    }
    
    // Day Month Year (15 January 2024)
    pattern = RegExp(r'^(\d{1,2})\s+(\w+)\s+(\d{2,4})$');
    match = pattern.firstMatch(lower);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final monthName = match.group(2)!;
      var year = int.parse(match.group(3)!);
      
      if (year < 100) year += year < 50 ? 2000 : 1900;
      
      final month = months[monthName];
      if (month != null && _isValidDate(year, month, day)) {
        return DateTime(year, month, day);
      }
    }
    
    return null;
  }
  
  /// Parse short textual dates (Jan 15 2024, 15 Jan, 10 Dec 2024)
  static DateTime? _parseShortTextualDate(String dateStr) {
    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      // Add full month names as well for robustness  
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
      // Additional international formats
      'jan.': 1, 'feb.': 2, 'mar.': 3, 'apr.': 4, 'may.': 5, 'jun.': 6,
      'jul.': 7, 'aug.': 8, 'sep.': 9, 'oct.': 10, 'nov.': 11, 'dec.': 12,
      'mai': 5, 'dez': 12, // International variants
    };
    
    final lower = dateStr.toLowerCase().trim();
    
    // Handle various short formats
    final patterns = [
      RegExp(r'^(\w{3,9}\.?)\s+(\d{1,2})\s+(\d{2,4})$'),  // Jan 15 2024, December 10 2024, Jan. 15 2024
      RegExp(r'^(\d{1,2})\s+(\w{3,9}\.?)\s+(\d{2,4})$'),  // 15 Jan 2024, 10 Dec 2024, 15 Jan. 2024
      RegExp(r'^(\d{1,2})\s+(\w{3,9}\.?)$'),              // 15 Jan (current year), 15 Jan.
      RegExp(r'^(\w{3,9}\.?)\s+(\d{1,2})$'),              // Jan 15 (current year), Jan. 15
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        String? monthName;
        int? day;
        int? year;
        
        if (pattern.pattern.startsWith(r'^(\w{3,9}')) {
          // Month first (Jan 15 2024, December 10 2024)
          monthName = match.group(1)!.replaceAll('.', '');
          day = int.parse(match.group(2)!);
          year = match.groupCount >= 3 ? int.tryParse(match.group(3)!) : null;
        } else {
          // Day first (15 Jan 2024, 10 Dec 2024)
          day = int.parse(match.group(1)!);
          monthName = match.group(2)!.replaceAll('.', '');
          year = match.groupCount >= 3 ? int.tryParse(match.group(3)!) : null;
        }
        
        year ??= DateTime.now().year; // Use current year if not specified
        if (year < 100) year += year < 50 ? 2000 : 1900;
        
        final month = months[monthName];
        if (month != null && _isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }
      }
    }
    
    return null;
  }
  
  /// Parse relative dates (just month/day, assume current year)
  static DateTime? _parseRelativeDate(String dateStr) {
    // This handles cases like "23 Jan" without year
    return _parseShortTextualDate(dateStr);
  }
  
  /// Parse ordinal dates (15th January 2024, 1st Jan)
  static DateTime? _parseOrdinalDate(String dateStr) {
    final cleaned = dateStr.replaceAll(RegExp(r'(\d+)(st|nd|rd|th)'), r'$1');
    return _parseTextualDate(cleaned) ?? _parseShortTextualDate(cleaned);
  }
  
  /// Parse compact date format (20240115)
  static DateTime? _parseCompactDate(String dateStr) {
    if (dateStr.length == 8) {
      try {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        
        if (_isValidDate(year, month, day)) {
          return DateTime(year, month, day);
        }
      } catch (e) {
        // Invalid format
      }
    }
    
    return null;
  }
  
  /// Parse week formats (Week 3, W3 2024)
  /// Note: Week parsing should be low priority - explicit dates should take precedence
  static DateTime? _parseWeekFormat(String dateStr) {
    final lower = dateStr.toLowerCase();
    final patterns = [
      RegExp(r'^week\s+(\d{1,2})\s+(\d{4})$'),
      RegExp(r'^w(\d{1,2})\s+(\d{4})$'),
      RegExp(r'^week\s+(\d{1,2})$'),
      RegExp(r'^w(\d{1,2})$'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final week = int.parse(match.group(1)!);
        // Use previous year for week 53 (since week 53 is usually end of December of previous year)
        var year = match.groupCount >= 2 ? 
            int.parse(match.group(2)!) : DateTime.now().year;
        
        if (week >= 1 && week <= 53) {
          // Week 53 usually refers to the last week of the previous year
          if (week == 53) {
            year = year - 1; // Week 53 is typically the last week of the previous year
          }
          
          // Calculate actual ISO week date (more accurate than simple arithmetic)
          final jan4 = DateTime(year, 1, 4); // January 4th is always in week 1
          final jan4Weekday = jan4.weekday; // Monday = 1, Sunday = 7
          final firstMondayOfYear = jan4.subtract(Duration(days: jan4Weekday - 1));
          final targetDate = firstMondayOfYear.add(Duration(days: (week - 1) * 7));
          
          return targetDate;
        }
      }
    }
    
    return null;
  }
  
  /// Parse month/year only (January 2024, Jan 24)
  static DateTime? _parseMonthYear(String dateStr) {
    final months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    
    final lower = dateStr.toLowerCase();
    final pattern = RegExp(r'^(\w+)\s+(\d{2,4})$');
    final match = pattern.firstMatch(lower);
    
    if (match != null) {
      final monthName = match.group(1)!;
      var year = int.parse(match.group(2)!);
      
      if (year < 100) year += year < 50 ? 2000 : 1900;
      
      final month = months[monthName];
      if (month != null && year >= 1900 && year <= 2100) {
        return DateTime(year, month, 1); // Use first day of month
      }
    }
    
    return null;
  }
  
  /// Parse year only (2024)
  static DateTime? _parseYearOnly(String dateStr) {
    final pattern = RegExp(r'^\d{4}$');
    if (pattern.hasMatch(dateStr)) {
      final year = int.parse(dateStr);
      if (year >= 1900 && year <= 2100) {
        return DateTime(year, 1, 1); // Use January 1st
      }
    }

    return null;
  }

  /// Parse year from text content (finds years in "Goals 2025", "2024 thoughts", etc.)
  /// Only matches if year appears to be the main subject (conservative approach)
  static DateTime? _parseYearFromText(String text) {
    // Only extract years from short titles/headers that seem year-focused
    if (text.length > 50) return null; // Skip long content
    
    final pattern = RegExp(r'\b(19|20)\d{2}\b');
    final matches = pattern.allMatches(text);
    
    // Only return year if it seems to be the main focus (goals, plans, etc.)
    final yearFocusedKeywords = RegExp(r'\b(goals?|plan|resolution|year|annual|review)\b', caseSensitive: false);
    
    for (final match in matches) {
      final yearStr = match.group(0)!;
      final year = int.parse(yearStr);
      
      if (year >= 2020 && year <= 2030) { // More restrictive year range for journals
        // Only use year parsing if text contains year-focused keywords
        if (yearFocusedKeywords.hasMatch(text)) {
          return DateTime(year, 1, 1); // Use January 1st of that year
        }
      }
    }
    
    return null;
  }
  
  /// Validate if date components form a valid date
  static bool _isValidDate(int year, int month, int day) {
    if (year < 1900 || year > 2100) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    
    try {
      DateTime(year, month, day);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parse enhanced textual dates with ordinals and journal patterns
  static DateTime? _parseEnhancedTextualDate(String dateStr) {
    final months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'jun': 6, 'jul': 7, 'aug': 8,
      'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    
    final lower = dateStr.toLowerCase().replaceAll(RegExp(r'[,]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Remove ordinal suffixes (1st -> 1, 2nd -> 2, etc.)
    final cleanedStr = lower.replaceAll(RegExp(r'(\d+)(?:st|nd|rd|th)'), r'$1');
    
    // Remove common journal words
    final processedStr = cleanedStr
        .replaceAll('today is ', '')
        .replaceAll('on ', '')
        .replaceAll(' of ', ' ')
        .trim();
    
    // Try different patterns
    List<RegExp> patterns = [
      // Month Day Year (January 15 2024)
      RegExp(r'^(\w+)\s+(\d{1,2})\s+(\d{2,4})$'),
      // Day Month Year (15 January 2024)  
      RegExp(r'^(\d{1,2})\s+(\w+)\s+(\d{2,4})$'),
      // Month Day (January 15) - use current year
      RegExp(r'^(\w+)\s+(\d{1,2})$'),
      // Day Month (15 January) - use current year
      RegExp(r'^(\d{1,2})\s+(\w+)$'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(processedStr);
      if (match != null) {
        final groups = [match.group(1)!, match.group(2)!];
        if (match.groupCount >= 3 && match.group(3) != null) {
          groups.add(match.group(3)!);
        }
        
        // Determine if first group is month or day
        final firstIsMonth = months.containsKey(groups[0]);
        final secondIsMonth = months.containsKey(groups[1]);
        
        if (firstIsMonth) {
          // Month Day [Year]
          final month = months[groups[0]]!;
          final day = int.parse(groups[1]);
          final year = groups.length > 2 ? 
              (int.parse(groups[2]) < 100 ? int.parse(groups[2]) + 2000 : int.parse(groups[2])) : 
              DateTime.now().year;
          
          if (_isValidDate(year, month, day)) {
            return DateTime(year, month, day);
          }
        } else if (secondIsMonth) {
          // Day Month [Year] 
          final day = int.parse(groups[0]);
          final month = months[groups[1]]!;
          final year = groups.length > 2 ? 
              (int.parse(groups[2]) < 100 ? int.parse(groups[2]) + 2000 : int.parse(groups[2])) : 
              DateTime.now().year;
          
          if (_isValidDate(year, month, day)) {
            return DateTime(year, month, day);
          }
        }
      }
    }
    
    return null;
  }
} 