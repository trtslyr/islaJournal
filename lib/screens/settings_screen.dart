import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import '../core/theme/app_theme.dart';

/// Settings screen for managing AI models and app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'settings',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.darkerCream,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'back',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
      body: Consumer<AIProvider>(
        builder: (context, aiProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildAISection(aiProvider),
              const SizedBox(height: 24),
              _buildStorageSection(aiProvider),
              const SizedBox(height: 24),
              _buildAboutSection(),
            ],
          );
        },
      ),
    );
  }

  /// AI Models section with model management
  Widget _buildAISection(AIProvider aiProvider) {
    return Container(
        padding: const EdgeInsets.all(16.0),
      color: AppTheme.darkerCream,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
              const Text(
                '🤖',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  color: AppTheme.warmBrown,
                ),
              ),
                const SizedBox(width: 8),
              const Text(
                'ai models',
                style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current model status indicator
            _buildCurrentModelStatus(aiProvider),
            const SizedBox(height: 16),
            
            // Available models list
            _buildAvailableModelsList(aiProvider),
            
            // Error display
            if (aiProvider.error != null) _buildErrorDisplay(aiProvider),
          ],
      ),
    );
  }

  /// Current model status indicator
  Widget _buildCurrentModelStatus(AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.creamBeige,
      child: Row(
        children: [
          Text(
            aiProvider.isModelLoaded ? '✓' : '○',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16.0,
              color: aiProvider.isModelLoaded ? AppTheme.warmBrown : AppTheme.mediumGray,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              aiProvider.isModelLoaded 
                ? 'ai ready: ${aiProvider.availableModels[aiProvider.currentModelId]?.name ?? 'unknown'}'
                : 'no ai model loaded',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Available models list
  Widget _buildAvailableModelsList(AIProvider aiProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'available models',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        ...aiProvider.availableModels.entries.map((entry) {
          final modelId = entry.key;
          final modelInfo = entry.value;
          final status = aiProvider.modelStatuses[modelId] ?? ModelStatus.notDownloaded;
          
          return _buildModelCard(aiProvider, modelId, modelInfo, status);
        }).toList(),
      ],
    );
  }

  /// Error display widget
  Widget _buildErrorDisplay(AIProvider aiProvider) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.creamBeige,
          child: Row(
            children: [
              const Text(
                '!',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  color: AppTheme.warningRed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  aiProvider.error!,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
                    color: AppTheme.warningRed,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => aiProvider.clearError(),
                child: const Text(
                  'dismiss',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Individual model card with download/load controls
  Widget _buildModelCard(AIProvider aiProvider, String modelId, AIModelInfo modelInfo, ModelStatus status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
      color: AppTheme.creamBeige,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model name and size
            Row(
              children: [
                Expanded(
                  child: Text(
                    modelInfo.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w600,
                    fontSize: 14.0,
                    ),
                  ),
                ),
                _buildModelSizeBadge(modelInfo.size),
              ],
            ),
            const SizedBox(height: 8),
            
            // Model status and controls
            _buildModelControls(aiProvider, modelId, modelInfo, status),
            
            // Download progress (if downloading)
            if (status == ModelStatus.downloading) 
              _buildDownloadProgress(aiProvider, modelId),
          ],
      ),
    );
  }

  /// Model size badge
  Widget _buildModelSizeBadge(AIModelSize size) {
    String sizeText;
    
    switch (size) {
      case AIModelSize.small:
        sizeText = 'small (~800mb)';
        break;
      case AIModelSize.medium:
        sizeText = 'medium (~2gb)';
        break;
      case AIModelSize.large:
        sizeText = 'large (~4.5gb)';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
      ),
      child: Text(
        sizeText,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10.0,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Model control buttons based on status
  Widget _buildModelControls(AIProvider aiProvider, String modelId, AIModelInfo modelInfo, ModelStatus status) {
    return Row(
      children: [
        _buildStatusIndicator(status),
        const Spacer(),
        
        // Action buttons based on status
        if (status == ModelStatus.notDownloaded) ...[
          TextButton(
            onPressed: aiProvider.isGenerating ? null : () => aiProvider.downloadModel(modelId),
            child: const Text(
              'download',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ] else if (status == ModelStatus.downloading) ...[
          const Text(
            'downloading...',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.mediumGray,
            ),
          ),
        ] else if (status == ModelStatus.downloaded) ...[
          TextButton(
            onPressed: aiProvider.isGenerating ? null : () => aiProvider.loadModel(modelId),
            child: const Text(
              'load',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildDeleteButton(aiProvider, modelId),
        ] else if (status == ModelStatus.loaded) ...[
          TextButton(
            onPressed: aiProvider.isGenerating ? null : () => aiProvider.unloadModel(),
            child: const Text(
              'unload',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildDeleteButton(aiProvider, modelId),
        ],
      ],
    );
  }

  /// Status indicator with text
  Widget _buildStatusIndicator(ModelStatus status) {
    String icon;
    String text;
    Color color;
    
    switch (status) {
      case ModelStatus.notDownloaded:
        icon = '↓';
        text = 'not downloaded';
        color = AppTheme.mediumGray;
        break;
      case ModelStatus.downloading:
        icon = '↓';
        text = 'downloading';
        color = AppTheme.warmBrown;
        break;
      case ModelStatus.downloaded:
        icon = '✓';
        text = 'downloaded';
        color = AppTheme.warmBrown;
        break;
      case ModelStatus.loaded:
        icon = '●';
        text = 'loaded';
        color = AppTheme.warmBrown;
        break;
      case ModelStatus.error:
        icon = '!';
        text = 'error';
        color = AppTheme.warningRed;
        break;
    }
    
    return Row(
      children: [
        Text(
          icon,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12.0,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Delete button for downloaded models
  Widget _buildDeleteButton(AIProvider aiProvider, String modelId) {
    return TextButton(
      onPressed: aiProvider.isGenerating ? null : () => _showDeleteConfirmation(aiProvider, modelId),
      child: const Text(
        'delete',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
          color: AppTheme.warningRed,
        ),
      ),
    );
  }

  /// Download progress indicator
  Widget _buildDownloadProgress(AIProvider aiProvider, String modelId) {
    final progress = aiProvider.currentDownload;
    if (progress == null || progress.percentage == 0) return const SizedBox.shrink();
    
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkerCream,
                  border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.percentage / 100,
                  child: Container(
                    color: AppTheme.warmBrown,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${progress.percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatBytes(progress.downloaded)} / ${_formatBytes(progress.total)}',
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10.0,
            color: AppTheme.mediumGray,
          ),
        ),
      ],
    );
  }

  /// Storage management section
  Widget _buildStorageSection(AIProvider aiProvider) {
    return Container(
        padding: const EdgeInsets.all(16.0),
      color: AppTheme.darkerCream,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Row(
              children: [
              Text(
                '💾',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  color: AppTheme.warmBrown,
                ),
              ),
              SizedBox(width: 8),
                Text(
                'storage',
                style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
            'downloaded models: ${aiProvider.downloadedModelsCount}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              ),
            ),
            const SizedBox(height: 8),
          TextButton(
              onPressed: () => _showStorageManagement(aiProvider),
            child: const Text(
              'storage details',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                fontWeight: FontWeight.w400,
              ),
              ),
            ),
          ],
      ),
    );
  }

  /// About section
  Widget _buildAboutSection() {
    return Container(
        padding: const EdgeInsets.all(16.0),
      color: AppTheme.darkerCream,
      child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
              Text(
                'ℹ',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  color: AppTheme.warmBrown,
                ),
              ),
              SizedBox(width: 8),
                Text(
                'about',
                style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          SizedBox(height: 16),
          Text(
            'isla journal',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
              fontSize: 16.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          SizedBox(height: 8),
          Text(
            'a private, ai-enhanced journaling app with local model support.',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
          SizedBox(height: 16),
          Text(
            'version: 2.0.0 (phase 2)',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
                color: AppTheme.mediumGray,
              ),
            ),
          ],
      ),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(AIProvider aiProvider, String modelId) {
    final modelInfo = aiProvider.availableModels[modelId];
    if (modelInfo == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'delete model',
          style: TextStyle(fontFamily: 'JetBrainsMono'),
        ),
                 content: Text(
          'delete ${modelInfo.name}?\n\nthis will free up storage space but you\'ll need to download it again to use it.',
           style: const TextStyle(fontFamily: 'JetBrainsMono'),
         ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'cancel',
              style: TextStyle(fontFamily: 'JetBrainsMono'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              aiProvider.deleteModel(modelId);
            },
            child: const Text(
              'delete',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                color: AppTheme.warningRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show storage management dialog
  void _showStorageManagement(AIProvider aiProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'storage management',
          style: TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        content: const Text(
          'storage features:\n\n• view detailed storage usage\n• clean up temporary files\n• manage model cache\n\nthese features will be available in a future update.',
          style: TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'close',
              style: TextStyle(fontFamily: 'JetBrainsMono'),
            ),
          ),
        ],
      ),
    );
  }

  /// Format bytes to human readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}b';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}kb';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)}mb';
    return '${(bytes / 1073741824).toStringAsFixed(1)}gb';
  }
} 