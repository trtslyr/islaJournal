import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/analytics_service.dart';
import '../providers/auto_tagging_provider.dart';
import '../core/theme/app_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  PersonalInsightsDashboard? _dashboard;
  bool _isLoading = true;
  String _selectedTimeRange = 'all_time';
  late TabController _tabController;

  final Map<String, String> _timeRanges = {
    'last_7_days': 'Last 7 Days',
    'last_30_days': 'Last 30 Days',
    'last_3_months': 'Last 3 Months',
    'all_time': 'All Time',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInsights();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _analyticsService.initialize();
      
      final now = DateTime.now();
      DateTime? startDate;
      
      switch (_selectedTimeRange) {
        case 'last_7_days':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'last_30_days':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case 'last_3_months':
          startDate = now.subtract(const Duration(days: 90));
          break;
        case 'all_time':
        default:
          startDate = null;
          break;
      }

      final dashboard = await _analyticsService.generateInsightsDashboard(
        startDate: startDate,
        endDate: now,
      );

      setState(() {
        _dashboard = dashboard;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading insights: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Insights'),
        backgroundColor: AppTheme.darkerCream,
        foregroundColor: AppTheme.darkText,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            onSelected: (value) {
              setState(() {
                _selectedTimeRange = value;
              });
              _loadInsights();
            },
            itemBuilder: (context) => _timeRanges.entries
                .map((entry) => PopupMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInsights,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.warmBrown,
          unselectedLabelColor: AppTheme.mediumGray,
          indicatorColor: AppTheme.warmBrown,
          labelStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Writing'),
            Tab(text: 'Mood'),
            Tab(text: 'Themes'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dashboard == null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildWritingTab(),
                    _buildMoodTab(),
                    _buildThemesTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.mediumGray,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load insights',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'JetBrainsMono',
              color: AppTheme.mediumGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start writing journal entries to see your personal insights',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'JetBrainsMono',
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadInsights,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final dashboard = _dashboard!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(dashboard),
          const SizedBox(height: 24),
          _buildGrowthInsights(dashboard.growthInsights),
          const SizedBox(height: 24),
          _buildRecentActivity(dashboard.writingStats),
        ],
      ),
    );
  }

  Widget _buildWritingTab() {
    final stats = _dashboard!.writingStats;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWritingStatsCards(stats),
          const SizedBox(height: 24),
          _buildWritingPatterns(stats),
          const SizedBox(height: 24),
          _buildLongestEntries(stats),
        ],
      ),
    );
  }

  Widget _buildMoodTab() {
    final mood = _dashboard!.moodTrends;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMoodSummary(mood),
          const SizedBox(height: 24),
          _buildEmotionFrequency(mood),
          const SizedBox(height: 24),
          _buildMoodInsights(mood),
        ],
      ),
    );
  }

  Widget _buildThemesTab() {
    final themes = _dashboard!.themeAnalysis;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopThemes(themes),
          const SizedBox(height: 24),
          _buildTopTags(themes),
          const SizedBox(height: 24),
          _buildEmergingTopics(themes),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(PersonalInsightsDashboard dashboard) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Entries',
          dashboard.writingStats.totalEntries.toString(),
          Icons.description,
          AppTheme.warmBrown,
        ),
        _buildStatCard(
          'Total Words',
          _formatNumber(dashboard.writingStats.totalWords),
          Icons.text_fields,
          Colors.green,
        ),
        _buildStatCard(
          'Mood Score',
          _formatMoodScore(dashboard.moodTrends.averageValence),
          Icons.mood,
          _getMoodColor(dashboard.moodTrends.averageValence),
        ),
        _buildStatCard(
          'Growth Trend',
          dashboard.growthInsights.overallTrend,
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'JetBrainsMono',
                    color: AppTheme.mediumGray,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthInsights(GrowthInsights insights) {
    return _buildSection(
      'Personal Growth',
      Icons.psychology,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator('Writing Consistency', insights.writingConsistency),
          const SizedBox(height: 12),
          _buildProgressIndicator('Emotional Growth', insights.emotionalGrowth),
          const SizedBox(height: 12),
          _buildProgressIndicator('Topic Diversity', insights.thematicDiversity),
          const SizedBox(height: 16),
          if (insights.personalityTraits.isNotEmpty) ...[
            Text(
              'Your Traits',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: insights.personalityTraits.map((trait) => 
                _buildChip(trait, AppTheme.warmBrown.withOpacity(0.1), AppTheme.warmBrown)
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'JetBrainsMono',
                color: AppTheme.mediumGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: AppTheme.mediumGray.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(WritingStats stats) {
    return _buildSection(
      'Recent Activity',
      Icons.history,
      Column(
        children: stats.recentActivity.take(5).map((activity) {
          final date = DateTime.parse(activity['date'] as String);
          return ListTile(
            leading: Icon(Icons.description, color: AppTheme.warmBrown),
            title: Text(
              activity['name'] as String,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${activity['wordCount']} words',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                color: AppTheme.mediumGray,
              ),
            ),
            trailing: Text(
              _formatRelativeDate(date),
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: AppTheme.mediumGray,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWritingStatsCards(WritingStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Avg Words/Entry',
          stats.averageWordsPerEntry.toStringAsFixed(0),
          Icons.text_fields,
          Colors.blue,
        ),
        _buildStatCard(
          'Writing Days',
          stats.writingDays.toString(),
          Icons.calendar_today,
          Colors.orange,
        ),
        _buildStatCard(
          'Entries/Week',
          stats.entriesPerWeek.toStringAsFixed(1),
          Icons.trending_up,
          Colors.green,
        ),
        _buildStatCard(
          'Longest Entry',
          stats.longestEntries.isNotEmpty 
              ? '${stats.longestEntries.first['wordCount']} words'
              : '0 words',
          Icons.article,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildWritingPatterns(WritingStats stats) {
    return _buildSection(
      'Writing Patterns',
      Icons.bar_chart,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By Day of Week',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...stats.writingByDayOfWeek.entries.map((entry) {
            final maxValue = stats.writingByDayOfWeek.values.reduce((a, b) => a > b ? a : b);
            final percentage = maxValue > 0 ? entry.value / maxValue : 0.0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: AppTheme.mediumGray.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLongestEntries(WritingStats stats) {
    return _buildSection(
      'Longest Entries',
      Icons.article,
      Column(
        children: stats.longestEntries.map((entry) {
          final date = DateTime.parse(entry['date'] as String);
          return ListTile(
            leading: Icon(Icons.description, color: AppTheme.warmBrown),
            title: Text(
              entry['name'] as String,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _formatRelativeDate(date),
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                color: AppTheme.mediumGray,
              ),
            ),
            trailing: Text(
              '${entry['wordCount']} words',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w600,
                color: AppTheme.warmBrown,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoodSummary(MoodTrends mood) {
    return _buildSection(
      'Mood Overview',
      Icons.mood,
      Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMoodMetric(
                  'Valence',
                  mood.averageValence,
                  'Positivity',
                  _getMoodColor(mood.averageValence),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMoodMetric(
                  'Arousal',
                  mood.averageArousal,
                  'Energy',
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMoodMetric(
                  'Stability',
                  mood.moodStability,
                  'Consistency',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warmBrown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Predominant Mood',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mood.predominantMood,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warmBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodMetric(String title, double value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatMoodValue(value),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'JetBrainsMono',
              color: AppTheme.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionFrequency(MoodTrends mood) {
    final topEmotions = mood.emotionFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _buildSection(
      'Top Emotions',
      Icons.favorite,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: topEmotions.take(10).map((emotion) {
          final intensity = emotion.value / (topEmotions.isNotEmpty ? topEmotions.first.value : 1);
          return _buildChip(
            '${emotion.key} (${emotion.value})',
            AppTheme.warmBrown.withOpacity(0.1 + (intensity * 0.3)),
            AppTheme.warmBrown,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoodInsights(MoodTrends mood) {
    return _buildSection(
      'Mood Insights',
      Icons.lightbulb,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mood.insights.map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.insights,
                size: 16,
                color: AppTheme.warmBrown,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    color: AppTheme.darkText,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildTopThemes(ThemeAnalysis themes) {
    return _buildSection(
      'Top Themes',
      Icons.topic,
      Column(
        children: themes.topThemes.take(8).map((theme) {
          final maxCount = themes.topThemes.isNotEmpty ? themes.topThemes.first['count'] as int : 1;
          final percentage = (theme['count'] as int) / maxCount;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    theme['name'] as String,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppTheme.mediumGray.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${theme['count']}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopTags(ThemeAnalysis themes) {
    return _buildSection(
      'Top Tags',
      Icons.label,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: themes.topTags.take(12).map((tag) {
          return _buildChip(
            '${tag['name']} (${tag['count']})',
            AppTheme.warmBrown.withOpacity(0.1),
            AppTheme.warmBrown,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmergingTopics(ThemeAnalysis themes) {
    return _buildSection(
      'Emerging Topics',
      Icons.trending_up,
      themes.emergingTopics.isEmpty
          ? Text(
              'No emerging topics detected yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'JetBrainsMono',
                color: AppTheme.mediumGray,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: themes.emergingTopics.map((topic) {
                return _buildChip(
                  topic,
                  Colors.green.withOpacity(0.1),
                  Colors.green,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warmBrown.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.warmBrown, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warmBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatMoodScore(double valence) {
    if (valence > 0.5) return 'Positive';
    if (valence > 0) return 'Slightly Positive';
    if (valence > -0.5) return 'Neutral';
    return 'Needs Care';
  }

  String _formatMoodValue(double value) {
    return (value * 100).toStringAsFixed(0);
  }

  Color _getMoodColor(double valence) {
    if (valence > 0.3) return Colors.green;
    if (valence > 0) return Colors.lightGreen;
    if (valence > -0.3) return Colors.orange;
    return Colors.red;
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()} weeks ago';
    return '${(difference.inDays / 30).floor()} months ago';
  }
} 