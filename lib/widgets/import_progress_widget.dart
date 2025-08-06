import 'package:flutter/material.dart';
import '../services/import_service.dart';
import '../core/theme/app_theme.dart';

class ImportProgressWidget extends StatelessWidget {
  final ImportProgress progress;
  
  const ImportProgressWidget({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _buildPhaseIcon(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importing Files',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                                                 color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    if (progress.currentFile != null)
                      Text(
                        progress.currentFile!,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                                                     color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Text(
                '${progress.current}/${progress.total}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Overall progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Progress',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mediumGray,
                ),
              ),
              SizedBox(height: 6),
              _buildProgressBar(
                progress.percentage,
                _getPhaseColor(),
                height: 8,
              ),
              SizedBox(height: 4),
              Text(
                '${(progress.percentage * 100).toInt()}%',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Phase description
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPhaseColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getPhaseColor().withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _buildPhaseIndicator(),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    progress.phaseDescription,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: AppTheme.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // AI Embedding progress (when applicable)
          if (progress.phase == ImportPhase.embedding && 
              progress.embeddingTotal != null && 
              progress.embeddingTotal! > 0) ...[
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 16,
                      color: AppTheme.warmBrown,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI Embedding Progress',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.darkText,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${progress.embeddingCurrent ?? 0}/${progress.embeddingTotal}',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _buildProgressBar(
                  progress.embeddingPercentage,
                  AppTheme.warmBrown,
                  height: 6,
                ),
                SizedBox(height: 4),
                Text(
                  'Processing content chunks for AI search...',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    color: AppTheme.mediumGray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseIcon() {
    switch (progress.phase) {
      case ImportPhase.starting:
        return Icon(Icons.play_arrow, color: AppTheme.mediumGray, size: 24);
      case ImportPhase.parsing:
        return Icon(Icons.description, color: Colors.blue, size: 24);
      case ImportPhase.storing:
        return Icon(Icons.save, color: Colors.green, size: 24);
      case ImportPhase.embedding:
        return Icon(Icons.psychology, color: AppTheme.warmBrown, size: 24);
      case ImportPhase.insights:
        return Icon(Icons.analytics, color: Colors.purple, size: 24);
      case ImportPhase.complete:
        return Icon(Icons.check_circle, color: Colors.green, size: 24);
      case ImportPhase.error:
        return Icon(Icons.error, color: Colors.red, size: 24);
    }
  }

  Widget _buildPhaseIndicator() {
    switch (progress.phase) {
      case ImportPhase.starting:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.mediumGray),
          ),
        );
      case ImportPhase.parsing:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case ImportPhase.storing:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        );
      case ImportPhase.embedding:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
          ),
        );
      case ImportPhase.insights:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        );
      case ImportPhase.complete:
        return Icon(Icons.check, color: Colors.green, size: 16);
      case ImportPhase.error:
        return Icon(Icons.close, color: Colors.red, size: 16);
    }
  }

  Color _getPhaseColor() {
    switch (progress.phase) {
      case ImportPhase.starting:
        return AppTheme.mediumGray;
      case ImportPhase.parsing:
        return Colors.blue;
      case ImportPhase.storing:
        return Colors.green;
      case ImportPhase.embedding:
        return AppTheme.warmBrown;
      case ImportPhase.insights:
        return Colors.purple;
      case ImportPhase.complete:
        return Colors.green;
      case ImportPhase.error:
        return Colors.red;
    }
  }

  Widget _buildProgressBar(double progress, Color color, {double height = 8}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.lightGray,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 