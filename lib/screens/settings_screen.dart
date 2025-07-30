import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/ai_provider.dart';
import '../providers/layout_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/license_provider.dart';
import '../widgets/license_dialog.dart';
import '../services/journal_companion_service.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/import_dialog.dart';

/// Settings screen for managing AI models and app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _tokenUsageKey = 'context_token_usage';
  double _currentTokens = 4000.0; // Updated default value to match new range
  bool _showLicenseKey = false;
  String? _currentLicenseKey;
  
  @override
  void initState() {
    super.initState();
    _loadTokenUsage();
  }
  
  /// Load saved token usage from SharedPreferences
  Future<void> _loadTokenUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTokens = prefs.getDouble(_tokenUsageKey);
      if (savedTokens != null) {
        // Clamp to new efficient range (2K-8K)
        final clampedTokens = savedTokens.clamp(2000.0, 8000.0);
        
        setState(() {
          _currentTokens = clampedTokens;
        });
        
        // If we clamped the value, save the new clamped value
        if (clampedTokens != savedTokens) {
          await prefs.setDouble(_tokenUsageKey, clampedTokens);
          print('📱 Clamped token usage from ${savedTokens.toInt()} to ${clampedTokens.toInt()} for efficiency');
        }
      } else {
        setState(() {
          _currentTokens = 4000.0; // Fallback to default if not found
        });
      }
    } catch (e) {
      print('Error loading token usage: $e');
      setState(() {
        _currentTokens = 4000.0; // Fallback to default on error
      });
    }
  }
  
  /// Save token usage to SharedPreferences
  Future<void> _saveTokenUsage(double tokens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_tokenUsageKey, tokens);
      setState(() {
        _currentTokens = tokens;
      });
    } catch (e) {
      print('Error saving token usage: $e');
    }
  }

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
      body: Consumer2<AIProvider, LicenseProvider>(
        builder: (context, aiProvider, licenseProvider, child) {
                      return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildAISection(aiProvider),
                const SizedBox(height: 24),
                _buildContextSection(),
                const SizedBox(height: 24),
                _buildImportExportSection(),
                const SizedBox(height: 24),
                _buildStorageSection(aiProvider),
                const SizedBox(height: 24),
                _buildLicenseSection(licenseProvider),
                const SizedBox(height: 24),
                _buildAboutSection(),
              ],
            );
        },
      ),
    );
  }

  /// License Status section showing current subscription/license info
  Widget _buildLicenseSection(LicenseProvider licenseProvider) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: AppTheme.darkerCream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Text(
                _getLicenseIcon(licenseProvider),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  color: AppTheme.warmBrown,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Account Status',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warmBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // License status display
          _buildLicenseStatusCard(licenseProvider),
          
          const SizedBox(height: 16),
          
          // Action buttons
          _buildLicenseActions(licenseProvider),
        ],
      ),
    );
  }

  String _getLicenseIcon(LicenseProvider licenseProvider) {
    if (licenseProvider.isLifetime) return '⭐';
    if (licenseProvider.isSubscription) return '💎';
    if (licenseProvider.isTrial) return '⏰';
    return '🔑';
  }

  Widget _buildLicenseStatusCard(LicenseProvider licenseProvider) {
    final status = licenseProvider.licenseStatus;
    
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: _getLicenseCardColor(licenseProvider),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: AppTheme.warmBrown.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // License type
          Text(
            _getLicenseTitle(licenseProvider),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 8),
          
          // License details
          Text(
            _getLicenseDescription(licenseProvider),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.mediumGray,
            ),
          ),
          
          // License key display (if shown)
          if (_showLicenseKey && _currentLicenseKey != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: AppTheme.darkerBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: AppTheme.darkerBrown.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'License Key:',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.0,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkerBrown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _currentLicenseKey!,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11.0,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Trial countdown if applicable
          if (licenseProvider.isTrial && status?.trialHoursRemaining != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: AppTheme.warmBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2.0),
              ),
              child: Text(
                '${status!.trialHoursRemaining} hours remaining',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warmBrown,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getLicenseCardColor(LicenseProvider licenseProvider) {
    if (licenseProvider.isLifetime) return AppTheme.warmBrown.withOpacity(0.1);
    if (licenseProvider.isSubscription) return AppTheme.darkerBrown.withOpacity(0.1);
    if (licenseProvider.isTrial) return AppTheme.creamBeige;
    return AppTheme.warningRed.withOpacity(0.1);
  }

  String _getLicenseTitle(LicenseProvider licenseProvider) {
    final status = licenseProvider.licenseStatus;
    
    if (licenseProvider.isLifetime) {
      return 'Lifetime License${status?.customerName != null ? ' - ${status!.customerName}' : ''}';
    }
    if (licenseProvider.isSubscription) {
      final planType = status?.planType ?? '';
      return '${planType.toUpperCase()} Subscription';
    }
    if (licenseProvider.isTrial) {
      return 'Free Trial Active';
    }
    return 'Unlicensed';
  }

  String _getLicenseDescription(LicenseProvider licenseProvider) {
    final status = licenseProvider.licenseStatus;
    
    if (licenseProvider.isLifetime) {
      return 'Full access forever • No expiration • Works offline';
    }
    if (licenseProvider.isSubscription) {
      if (status?.expiresAt != null) {
        final expiryDate = status!.expiresAt!;
        final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
        return 'Renews in $daysUntilExpiry days • Full access • Manage via customer portal';
      }
      return 'Active subscription • Full access';
    }
    if (licenseProvider.isTrial) {
      return 'Full access during trial period • Upgrade anytime';
    }
    return 'Trial expired • Please upgrade to continue using';
  }

  Widget _buildLicenseActions(LicenseProvider licenseProvider) {
    return Row(
      children: [
        // Manage subscription button (subscription users only)
        if (licenseProvider.isSubscription) ...[
          ElevatedButton(
            onPressed: () => _openSubscriptionManagement(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warmBrown,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Manage Subscription',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        
        // Show license key for subscription users only
        if (licenseProvider.isSubscription) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _toggleLicenseKeyVisibility,
              style: ElevatedButton.styleFrom(
                backgroundColor: _showLicenseKey ? AppTheme.mediumGray : AppTheme.darkerBrown,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                _showLicenseKey ? 'Hide Key' : 'Show Key',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                ),
              ),
            ),
          ],
        
        // Upgrade button (for trial users)
        if (licenseProvider.isTrial) ...[
          ElevatedButton(
            onPressed: () => _openUpgradeOptions(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkerBrown,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Upgrade Now',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
              ),
            ),
          ),
        ],
        
        // License expired - upgrade button
        if (licenseProvider.needsLicense) ...[
          ElevatedButton(
            onPressed: () => _openUpgradeOptions(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningRed,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Activate License',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
              ),
            ),
          ),
        ],
        
        // Add some space before debug section
        const Spacer(),
        
        // 🧪 TESTING: Logout button (for testing different license states)
        ElevatedButton(
          onPressed: () => _logoutForTesting(licenseProvider),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mediumGray,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text(
            '🧪 Logout (Testing)',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: Colors.black54,
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 🧪 TESTING: Reset trial button  
        ElevatedButton(
          onPressed: () => _resetTrialForTesting(licenseProvider),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mediumGray,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text(
            '🔄 Reset Trial',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  // Open subscription management (Stripe customer portal)
  Future<void> _openSubscriptionManagement() async {
    try {
      const portalUrl = 'https://pay.islajournal.app/p/login/cNieVc50A7yGfkv4BQ73G00';
      await launchUrl(Uri.parse(portalUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening subscription management: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }

  Future<void> _openUpgradeOptions() async {
    // Show license dialog
    showDialog(
      context: context,
      builder: (context) => LicenseDialog(canDismiss: true),
    );
  }

  // 🧪 TESTING: Clear all license data and revert to trial
  Future<void> _logoutForTesting(LicenseProvider licenseProvider) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBeige,
        title: const Text(
          '🧪 Testing Logout',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'This will clear all license data and revert to trial mode.\n\nThis is for testing purposes only.',
          style: TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningRed),
            child: const Text('Clear License Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear all license data
        await licenseProvider.clearLicenseData();
        
        // Reinitialize to start fresh trial
        await licenseProvider.initialize();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ License data cleared! Reverted to trial mode.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error clearing license data: $e'),
              backgroundColor: AppTheme.warningRed,
            ),
          );
        }
      }
    }
  }

  // 🧪 TESTING: Reset trial period
  Future<void> _resetTrialForTesting(LicenseProvider licenseProvider) async {
    try {
      // Reset trial period
      await licenseProvider.resetTrial();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Trial period reset! Starting fresh 24-hour trial.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error resetting trial: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }
  
  // Toggle license key visibility
  Future<void> _toggleLicenseKeyVisibility() async {
    if (!_showLicenseKey) {
      // Load the license key from storage
      try {
        final storage = FlutterSecureStorage();
        String? licenseKey;
        
        // Try lifetime key first
        licenseKey = await storage.read(key: 'license_key');
        
        // If no lifetime key, try subscription key
        if (licenseKey == null) {
          licenseKey = await storage.read(key: 'subscription_key');
        }
        
        // Fallback to SharedPreferences if secure storage fails
        if (licenseKey == null) {
          final prefs = await SharedPreferences.getInstance();
          licenseKey = prefs.getString('license_key') ?? prefs.getString('subscription_key');
        }
        
        setState(() {
          _currentLicenseKey = licenseKey ?? 'No license key found';
          _showLicenseKey = true;
        });
      } catch (e) {
        debugPrint('Error loading license key: $e');
        setState(() {
          _currentLicenseKey = 'Error loading key';
          _showLicenseKey = true;
        });
      }
    } else {
      setState(() {
        _showLicenseKey = false;
        _currentLicenseKey = null;
      });
    }
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
    final modelStatus = aiProvider.modelStatuses[modelId] ?? ModelStatus.notDownloaded;
    
    // Show progress indicator if model is downloading OR if we have progress data
    if (progress == null && modelStatus != ModelStatus.downloading) {
      return const SizedBox.shrink();
    }
    
    // If model is downloading but no progress yet, show initial state
    if (progress == null && modelStatus == ModelStatus.downloading) {
      return Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkerCream,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warmBrown.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Initializing download...',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.warmBrown,
                    ),
                  ),
                ),
                // Cancel button
                InkWell(
                  onTap: () => _showCancelDownloadDialog(aiProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.warningRed.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'cancel',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.0,
                        color: AppTheme.warningRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    return Column(
      children: [
        const SizedBox(height: 12),
        
        // Enhanced progress bar with animation
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.darkerCream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.warmBrown.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status header with cancel button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progress?.status ?? 'Downloading...',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.warmBrown,
                      ),
                    ),
                  ),
                  // Cancel button
                  if ((progress?.percentage ?? 0) < 100)
                    InkWell(
                      onTap: () => _showCancelDownloadDialog(aiProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.warningRed.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'cancel',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10.0,
                            color: AppTheme.warningRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Animated progress bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.creamBeige,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppTheme.warmBrown.withOpacity(0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ((progress?.percentage ?? 0) / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: (progress?.percentage ?? 0) >= 100 
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : [AppTheme.warmBrown, AppTheme.warmBrown.withOpacity(0.8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Progress details row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Percentage
                  Text(
                    '${(progress?.percentage ?? 0).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warmBrown,
                    ),
                  ),
                  
                  // Download stats
                  Text(
                    '${_formatBytes(progress?.downloaded ?? 0)} / ${_formatBytes(progress?.total ?? 0)}',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.0,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
              
              // Download speed and ETA (if downloading)
              if ((progress?.percentage ?? 0) < 100 && (progress?.percentage ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Download speed
                    Text(
                      progress?.formattedSpeed ?? 'calculating...',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.0,
                        color: AppTheme.mediumGray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    
                    // ETA
                    Text(
                      progress?.formattedETA ?? 'calculating...',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.0,
                        color: AppTheme.mediumGray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Completion status
              if ((progress?.percentage ?? 0) >= 100) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Download completed successfully!',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.0,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Show cancel download confirmation dialog
  void _showCancelDownloadDialog(AIProvider aiProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBeige,
        title: const Text(
          'Cancel Download',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to cancel the download?\n\nPartial downloads can be resumed later.',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continue Download',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              aiProvider.cancelDownload();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Download cancelled. You can resume it later.',
                    style: TextStyle(fontFamily: 'JetBrainsMono'),
                  ),
                  backgroundColor: AppTheme.warmBrown,
                ),
              );
            },
            child: const Text(
              'Cancel Download',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                color: AppTheme.warningRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Context settings section with token usage slider
  Widget _buildContextSection() {
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
                '🧠',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  color: AppTheme.warmBrown,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Context Settings',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warmBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Token usage slider
          _buildTokenUsageSlider(),
          
          const SizedBox(height: 16),
          

          
          // Explanation text
          Text(
            'Higher token usage = more recent files included in full text (not summarized). '
            'Lower usage = more files compressed to summaries for efficiency.',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.warmBrown.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Token usage slider widget
  Widget _buildTokenUsageSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Token Usage per Query',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: AppTheme.warmBrown,
          ),
        ),
        const SizedBox(height: 8),
        
        Row(
          children: [
            Text(
              '2K',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                color: AppTheme.warmBrown.withOpacity(0.7),
              ),
            ),
            Expanded(
              child: Slider(
                value: _currentTokens,
                min: 2000.0,
                max: 8000.0,
                divisions: 6, // 2K, 3K, 4K, 5K, 6K, 7K, 8K
                activeColor: AppTheme.warmBrown,
                inactiveColor: AppTheme.warmBrown.withOpacity(0.3),
                onChanged: (value) {
                  // Save immediately when user changes the value
                  _saveTokenUsage(value);
                },
              ),
            ),
            Text(
              '8K',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                color: AppTheme.warmBrown.withOpacity(0.7),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Current value display
        Center(
          child: Text(
            '${(_currentTokens / 1000).toInt()}K tokens',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
              color: AppTheme.warmBrown,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Device recommendations
        _buildDeviceRecommendations(_currentTokens),
        
        const SizedBox(height: 8),
        
        // System explanation
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.creamBeige.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
                                'Core context (profile + conversation) uses ~400 tokens. Your setting controls embedding search depth - higher settings find more relevant journal entries. AI responses are capped at ~1024 tokens for thoughtful but complete answers.',
                    style: TextStyle(
              fontSize: 11.0,
              color: AppTheme.mediumGray,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }



  /// Get current token usage setting (static method for other classes to use)
  static Future<double> getCurrentTokenUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_tokenUsageKey) ?? 30000.0;
    } catch (e) {
      print('Error loading token usage: $e');
      return 30000.0;
    }
  }

  /// Device recommendations based on token usage
  Widget _buildDeviceRecommendations(double tokens) {
    String recommendation;
    Color color;
    
    if (tokens <= 3000) {
      recommendation = '📱 Optimal for mobile devices';
      color = Colors.green;
    } else if (tokens <= 5000) {
      recommendation = '💻 Good for tablets/laptops';
      color = Colors.orange;
    } else {
      recommendation = '🖥️ High-performance devices';
      color = Colors.blue;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        recommendation,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12.0,
          color: color.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Import & Export section for managing journal content
  Widget _buildImportExportSection() {
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
                '📁',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  color: AppTheme.warmBrown,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'import & export',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Import files section
          _buildImportOption(),
          
          const SizedBox(height: 12),
          
          // Date refresh section
          _buildDateRefreshOption(),
          
          const SizedBox(height: 12),
          
          // Export section (placeholder for future implementation)
          _buildExportOption(),
          
          const SizedBox(height: 24),
          
          // Danger zone section
          _buildDangerZone(),
        ],
      ),
    );
  }

  Widget _buildImportOption() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.creamBeige,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.file_upload,
                size: 20,
                color: AppTheme.warmBrown,
              ),
              const SizedBox(width: 8),
              const Text(
                'import files',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Import markdown files (.md) from your computer into your journal.',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.mediumGray,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Import Markdown Files',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warmBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRefreshOption() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.creamBeige,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.date_range,
                size: 20,
                color: AppTheme.warmBrown,
              ),
              SizedBox(width: 8),
              Text(
                'refresh dates',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Re-scan all files to extract and update journal dates for chronological sorting.',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.mediumGray,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _refreshJournalDates,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text(
                'Refresh All Journal Dates',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warmBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.creamBeige,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.file_download,
                size: 20,
                color: AppTheme.mediumGray,
              ),
              const SizedBox(width: 8),
              const Text(
                'export journal',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Export your journal entries to various formats. (Coming soon)',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.mediumGray,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null, // Disabled for now
              icon: const Icon(Icons.download, size: 16),
              label: const Text(
                'Export Journal (Coming Soon)',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mediumGray,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => ImportDialog(),
    );
  }

  Future<void> _refreshJournalDates() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBeige,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
            ),
            const SizedBox(height: 16),
            const Text(
              'Refreshing journal dates...',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Refresh dates using the journal provider
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      await journalProvider.refreshJournalDates();
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Journal dates refreshed successfully!',
            style: TextStyle(fontFamily: 'JetBrainsMono'),
          ),
          backgroundColor: AppTheme.warmBrown,
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error refreshing dates: $e',
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning,
                size: 20,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Text(
                'danger zone',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Irreversible actions that will permanently delete all your data.',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          
          // Delete all data button (most destructive)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showDeleteAllDataDialog,
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const Text(
                'Delete All Data',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }





  Future<void> _showDeleteAllDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBeige,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Delete All Data',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• All journal files and folders\n'
              '• All AI conversations\n'
              '• All file embeddings and insights\n'
              '• All import history',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Delete All Data',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAllData();
    }
  }

  Future<void> _deleteAllData() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBeige,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deleting all data...',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Delete all data using the journal provider
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      await journalProvider.deleteAllData();
      
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All data deleted successfully!',
            style: TextStyle(fontFamily: 'JetBrainsMono'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting data: $e',
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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