import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import '../core/theme/app_theme.dart';

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
        title: const Text('Settings'),
        backgroundColor: AppTheme.darkerCream,
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

  Widget _buildAISection(AIProvider aiProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: AppTheme.warmBrown),
                const SizedBox(width: 8),
                Text(
                  'AI Models',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current model status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkerCream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    aiProvider.isModelLoaded ? Icons.check_circle : Icons.circle_outlined,
                    color: aiProvider.isModelLoaded ? Colors.green : AppTheme.mediumGray,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiProvider.isModelLoaded 
                        ? 'AI Ready: ${aiProvider.availableModels[aiProvider.currentModelId]?.name ?? 'Unknown'}'
                        : 'No AI model loaded',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Available models
            Text(
              'Available Models',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'JetBrainsMono',
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
            
            if (aiProvider.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        aiProvider.error!,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          color: Colors.red.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => aiProvider.clearError(),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(AIProvider aiProvider, String modelId, AIModelInfo modelInfo, ModelStatus status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modelInfo.name,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getModelDescription(modelInfo),
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 14,
                          color: AppTheme.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildModelStatusBadge(status),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Download progress
            if (status == ModelStatus.downloading && aiProvider.currentDownload != null) ...[
              LinearProgressIndicator(
                value: aiProvider.currentDownload!.percentage / 100,
                backgroundColor: AppTheme.darkerCream,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
              ),
              const SizedBox(height: 8),
              Text(
                aiProvider.currentDownload!.status,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Action buttons
            Row(
              children: [
                if (status == ModelStatus.notDownloaded) ...[
                  ElevatedButton.icon(
                    onPressed: () => aiProvider.downloadModel(modelId),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warmBrown,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _showManualDownloadDialog(modelId, modelInfo),
                    child: const Text('Manual Download'),
                  ),
                ],
                
                if (status == ModelStatus.downloading) ...[
                  ElevatedButton.icon(
                    onPressed: () => aiProvider.cancelDownload(),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                
                if (status == ModelStatus.downloaded) ...[
                  ElevatedButton.icon(
                    onPressed: () => aiProvider.loadModel(modelId),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Load'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showDeleteConfirmation(aiProvider, modelId, modelInfo.name),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
                
                if (status == ModelStatus.loaded) ...[
                  ElevatedButton.icon(
                    onPressed: () => aiProvider.unloadModel(),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Unload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
                
                if (status == ModelStatus.error) ...[
                  ElevatedButton.icon(
                    onPressed: () => aiProvider.downloadModel(modelId),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warmBrown,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatusBadge(ModelStatus status) {
    Color color;
    String text;
    IconData icon;
    
    switch (status) {
      case ModelStatus.notDownloaded:
        color = AppTheme.mediumGray;
        text = 'Not Downloaded';
        icon = Icons.cloud_download;
        break;
      case ModelStatus.downloading:
        color = Colors.blue;
        text = 'Downloading';
        icon = Icons.download;
        break;
      case ModelStatus.downloaded:
        color = Colors.green;
        text = 'Downloaded';
        icon = Icons.check_circle;
        break;
      case ModelStatus.loaded:
        color = Colors.green;
        text = 'Loaded';
        icon = Icons.check_circle;
        break;
      case ModelStatus.error:
        color = Colors.red;
        text = 'Error';
        icon = Icons.error;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageSection(AIProvider aiProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage, color: AppTheme.warmBrown),
                const SizedBox(width: 8),
                Text(
                  'Storage',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            FutureBuilder<String>(
              future: aiProvider.getStorageUsageFormatted(),
              builder: (context, snapshot) {
                return ListTile(
                  leading: const Icon(Icons.folder, color: AppTheme.mediumGray),
                  title: const Text(
                    'AI Models Storage',
                    style: TextStyle(fontFamily: 'JetBrainsMono'),
                  ),
                  subtitle: Text(
                    snapshot.data ?? 'Calculating...',
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                  ),
                  trailing: TextButton(
                    onPressed: () => _showStorageManagement(aiProvider),
                    child: const Text('Manage'),
                  ),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.info, color: AppTheme.mediumGray),
              title: const Text(
                'Downloaded Models',
                style: TextStyle(fontFamily: 'JetBrainsMono'),
              ),
              subtitle: Text(
                '${aiProvider.downloadedModelsCount} of ${aiProvider.availableModels.length} models',
                style: const TextStyle(fontFamily: 'JetBrainsMono'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: AppTheme.warmBrown),
                const SizedBox(width: 8),
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            const ListTile(
              leading: Icon(Icons.auto_stories, color: AppTheme.mediumGray),
              title: Text(
                'Isla Journal',
                style: TextStyle(fontFamily: 'JetBrainsMono'),
              ),
              subtitle: Text(
                'Your private, offline journaling companion',
                style: TextStyle(fontFamily: 'JetBrainsMono'),
              ),
            ),
            
            const ListTile(
              leading: Icon(Icons.privacy_tip, color: AppTheme.mediumGray),
              title: Text(
                'Privacy First',
                style: TextStyle(fontFamily: 'JetBrainsMono'),
              ),
              subtitle: Text(
                'All your data and AI processing stays on your device',
                style: TextStyle(fontFamily: 'JetBrainsMono'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModelDescription(AIModelInfo modelInfo) {
    final sizeText = _formatBytes(modelInfo.fileSizeBytes);
    final sizeDesc = switch (modelInfo.size) {
      AIModelSize.small => 'Fast, efficient for basic features',
      AIModelSize.medium => 'Balanced performance and quality',
      AIModelSize.large => 'Best quality, requires more resources',
    };
    return '$sizeText • $sizeDesc';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showManualDownloadDialog(String modelId, AIModelInfo modelInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Manual Download - ${modelInfo.name}',
          style: const TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'If automatic download fails, you can download manually:',
                style: TextStyle(fontFamily: 'JetBrainsMono'),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkerCream,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Download from:',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      modelInfo.downloadUrl,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '2. Save as: ${modelInfo.fileName}',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '3. Place in your models directory',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The app will automatically detect it',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(AIProvider aiProvider, String modelId, String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Model',
          style: const TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        content: Text(
          'Are you sure you want to delete "$modelName"?\n\nThis will permanently remove the model file from your device.',
          style: const TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              aiProvider.deleteModel(modelId);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showStorageManagement(AIProvider aiProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Storage Management',
          style: TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        content: const Text(
          'Storage management features:\n\n• View detailed storage usage\n• Clean up temporary files\n• Manage model cache\n\nThese features will be available in a future update.',
          style: TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 