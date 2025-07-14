class MoodPattern {
  final double averageValence;
  final double averageArousal;
  final Map<String, int> emotionFrequency;
  final String trend; // 'improving', 'declining', 'stable'
  final int totalEntries;

  MoodPattern({
    required this.averageValence,
    required this.averageArousal,
    required this.emotionFrequency,
    required this.trend,
    required this.totalEntries,
  });

  Map<String, dynamic> toMap() {
    return {
      'averageValence': averageValence,
      'averageArousal': averageArousal,
      'emotionFrequency': emotionFrequency,
      'trend': trend,
      'totalEntries': totalEntries,
    };
  }

  factory MoodPattern.fromMap(Map<String, dynamic> map) {
    return MoodPattern(
      averageValence: map['averageValence'] as double,
      averageArousal: map['averageArousal'] as double,
      emotionFrequency: Map<String, int>.from(map['emotionFrequency']),
      trend: map['trend'] as String,
      totalEntries: map['totalEntries'] as int,
    );
  }
}

class WritingStats {
  final int totalEntries;
  final int totalWords;
  final double averageWordsPerEntry;
  final int writingDays;
  final double entriesPerWeek;
  final Map<String, int> writingByDayOfWeek;
  final Map<String, int> writingByMonth;
  final List<Map<String, dynamic>> longestEntries;
  final List<Map<String, dynamic>> recentActivity;

  WritingStats({
    required this.totalEntries,
    required this.totalWords,
    required this.averageWordsPerEntry,
    required this.writingDays,
    required this.entriesPerWeek,
    required this.writingByDayOfWeek,
    required this.writingByMonth,
    required this.longestEntries,
    required this.recentActivity,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalEntries': totalEntries,
      'totalWords': totalWords,
      'averageWordsPerEntry': averageWordsPerEntry,
      'writingDays': writingDays,
      'entriesPerWeek': entriesPerWeek,
      'writingByDayOfWeek': writingByDayOfWeek,
      'writingByMonth': writingByMonth,
      'longestEntries': longestEntries,
      'recentActivity': recentActivity,
    };
  }

  factory WritingStats.fromMap(Map<String, dynamic> map) {
    return WritingStats(
      totalEntries: map['totalEntries'] as int,
      totalWords: map['totalWords'] as int,
      averageWordsPerEntry: map['averageWordsPerEntry'] as double,
      writingDays: map['writingDays'] as int,
      entriesPerWeek: map['entriesPerWeek'] as double,
      writingByDayOfWeek: Map<String, int>.from(map['writingByDayOfWeek']),
      writingByMonth: Map<String, int>.from(map['writingByMonth']),
      longestEntries: List<Map<String, dynamic>>.from(map['longestEntries']),
      recentActivity: List<Map<String, dynamic>>.from(map['recentActivity']),
    );
  }
}

class MoodTrends {
  final MoodPattern currentPattern;
  final List<Map<String, dynamic>> weeklyTrends;
  final List<Map<String, dynamic>> monthlyTrends;
  final Map<String, double> emotionTrends;
  final String overallTrend;

  MoodTrends({
    required this.currentPattern,
    required this.weeklyTrends,
    required this.monthlyTrends,
    required this.emotionTrends,
    required this.overallTrend,
  });

  Map<String, dynamic> toMap() {
    return {
      'currentPattern': currentPattern.toMap(),
      'weeklyTrends': weeklyTrends,
      'monthlyTrends': monthlyTrends,
      'emotionTrends': emotionTrends,
      'overallTrend': overallTrend,
    };
  }

  factory MoodTrends.fromMap(Map<String, dynamic> map) {
    return MoodTrends(
      currentPattern: MoodPattern.fromMap(map['currentPattern']),
      weeklyTrends: List<Map<String, dynamic>>.from(map['weeklyTrends']),
      monthlyTrends: List<Map<String, dynamic>>.from(map['monthlyTrends']),
      emotionTrends: Map<String, double>.from(map['emotionTrends']),
      overallTrend: map['overallTrend'] as String,
    );
  }
}

class ThemeAnalysis {
  final List<Map<String, dynamic>> topThemes;
  final List<Map<String, dynamic>> emergingThemes;
  final List<Map<String, dynamic>> themeEvolution;
  final Map<String, int> themeFrequency;

  ThemeAnalysis({
    required this.topThemes,
    required this.emergingThemes,
    required this.themeEvolution,
    required this.themeFrequency,
  });

  Map<String, dynamic> toMap() {
    return {
      'topThemes': topThemes,
      'emergingThemes': emergingThemes,
      'themeEvolution': themeEvolution,
      'themeFrequency': themeFrequency,
    };
  }

  factory ThemeAnalysis.fromMap(Map<String, dynamic> map) {
    return ThemeAnalysis(
      topThemes: List<Map<String, dynamic>>.from(map['topThemes']),
      emergingThemes: List<Map<String, dynamic>>.from(map['emergingThemes']),
      themeEvolution: List<Map<String, dynamic>>.from(map['themeEvolution']),
      themeFrequency: Map<String, int>.from(map['themeFrequency']),
    );
  }
}

class GrowthInsights {
  final List<String> keyInsights;
  final List<Map<String, dynamic>> patterns;
  final List<Map<String, dynamic>> milestones;
  final Map<String, dynamic> recommendations;

  GrowthInsights({
    required this.keyInsights,
    required this.patterns,
    required this.milestones,
    required this.recommendations,
  });

  Map<String, dynamic> toMap() {
    return {
      'keyInsights': keyInsights,
      'patterns': patterns,
      'milestones': milestones,
      'recommendations': recommendations,
    };
  }

  factory GrowthInsights.fromMap(Map<String, dynamic> map) {
    return GrowthInsights(
      keyInsights: List<String>.from(map['keyInsights']),
      patterns: List<Map<String, dynamic>>.from(map['patterns']),
      milestones: List<Map<String, dynamic>>.from(map['milestones']),
      recommendations: Map<String, dynamic>.from(map['recommendations']),
    );
  }
}

class PersonalInsightsDashboard {
  final WritingStats writingStats;
  final MoodTrends moodTrends;
  final ThemeAnalysis themeAnalysis;
  final GrowthInsights growthInsights;
  final DateTime generatedAt;
  final String timeRange;

  PersonalInsightsDashboard({
    required this.writingStats,
    required this.moodTrends,
    required this.themeAnalysis,
    required this.growthInsights,
    required this.generatedAt,
    required this.timeRange,
  });

  Map<String, dynamic> toMap() {
    return {
      'writingStats': writingStats.toMap(),
      'moodTrends': moodTrends.toMap(),
      'themeAnalysis': themeAnalysis.toMap(),
      'growthInsights': growthInsights.toMap(),
      'generatedAt': generatedAt.toIso8601String(),
      'timeRange': timeRange,
    };
  }

  factory PersonalInsightsDashboard.fromMap(Map<String, dynamic> map) {
    return PersonalInsightsDashboard(
      writingStats: WritingStats.fromMap(map['writingStats']),
      moodTrends: MoodTrends.fromMap(map['moodTrends']),
      themeAnalysis: ThemeAnalysis.fromMap(map['themeAnalysis']),
      growthInsights: GrowthInsights.fromMap(map['growthInsights']),
      generatedAt: DateTime.parse(map['generatedAt'] as String),
      timeRange: map['timeRange'] as String,
    );
  }
}