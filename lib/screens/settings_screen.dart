import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';  // Removed for simpler Windows deployment
import '../providers/ai_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/license_provider.dart';
import '../services/ai_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/import_dialog.dart';
import '../services/browser_service.dart';


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
  // Removed _isModelsExpanded - using simple Ollama status instead

  // License key input controller
  final TextEditingController _licenseKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTokenUsage();
    _loadStoredLicenseKey();
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
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
          debugPrint(
              '📱 Clamped token usage from ${savedTokens.toInt()} to ${clampedTokens.toInt()} for efficiency');
        }
      } else {
        setState(() {
          _currentTokens = 4000.0; // Fallback to default if not found
        });
      }
    } catch (e) {
      debugPrint('Error loading token usage: $e');
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
      debugPrint('Error saving token usage: $e');
    }
  }

  /// Load stored license key from SharedPreferences
  Future<void> _loadStoredLicenseKey() async {
    try {
      // Use SharedPreferences directly for simpler Windows deployment
      final prefs = await SharedPreferences.getInstance();
      String? licenseKey = prefs.getString('license_key') ??
          prefs.getString('subscription_key');

      if (licenseKey != null && mounted) {
        setState(() {
          _currentLicenseKey = licenseKey;
          _showLicenseKey = false; // Hide by default
          _licenseKeyController.text =
              licenseKey; // Use null assertion since we checked above
        });
      }
    } catch (e) {
      debugPrint('Error loading stored license key: $e');
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
              _buildLicenseSection(licenseProvider),
              const SizedBox(height: 24),
              _buildAISection(aiProvider),
              const SizedBox(height: 24),
              _buildContextSection(),
              const SizedBox(height: 24),
              _buildImportExportSection(),
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
                'Account',
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

          // License key input section (for all users)
          _buildLicenseKeyInput(licenseProvider),

          const SizedBox(height: 16),

          // License Management buttons
          _buildLicenseManagement(),

          const SizedBox(height: 16),

          // Independent login button (always visible)
          _buildIndependentLoginButton(),

          const SizedBox(height: 16),

          // Action buttons based on license type
          _buildLicenseActions(licenseProvider),
        ],
      ),
    );
  }

  String _getLicenseIcon(LicenseProvider licenseProvider) {
    if (licenseProvider.isLifetime) return '⭐';
    if (licenseProvider.isSubscription) return '💎';
    return '🔑';
  }

  Widget _buildLicenseStatusCard(LicenseProvider licenseProvider) {

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
        ],
      ),
    );
  }

  Color _getLicenseCardColor(LicenseProvider licenseProvider) {
    if (licenseProvider.isLifetime) return AppTheme.warmBrown.withOpacity(0.1);
    if (licenseProvider.isSubscription) {
      return AppTheme.darkerBrown.withOpacity(0.1);
    }
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

    return 'License required • Please enter a valid license key';
  }

  /// License key input section (visible for all users)
  Widget _buildLicenseKeyInput(LicenseProvider licenseProvider) {
    final hasValidKey = licenseProvider.isValid;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppTheme.creamBeige,
        border: Border.all(color: AppTheme.mediumGray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'License Key',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              Spacer(),
              if (hasValidKey && _currentLicenseKey != null) ...[
                TextButton(
                  onPressed: _toggleLicenseKeyVisibility,
                  child: Text(
                    _showLicenseKey ? 'Hide' : 'Show',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      color: AppTheme.warmBrown,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _licenseKeyController,
                  readOnly:
                      hasValidKey, // Make read-only when license is active
                  obscureText: !_showLicenseKey && hasValidKey,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: hasValidKey ? AppTheme.darkText : AppTheme.darkText,
                  ),
                  decoration: InputDecoration(
                    hintText: hasValidKey
                        ? null
                        : 'Enter your license key (ij_life_... or ij_sub_...)',
                    hintStyle: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      color: AppTheme.mediumGray,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color:
                              hasValidKey ? Colors.green : AppTheme.mediumGray),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color:
                              hasValidKey ? Colors.green : AppTheme.mediumGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color:
                              hasValidKey ? Colors.green : AppTheme.warmBrown),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: hasValidKey
                        ? Colors.green.withOpacity(0.1)
                        : Colors.white,
                  ),
                  onChanged: hasValidKey
                      ? null
                      : (value) {
                          setState(() {
                            if (value.isEmpty) {
                              _currentLicenseKey = null;
                            }
                          });
                        },
                ),
              ),
              const SizedBox(width: 8),
              if (!hasValidKey) ...[
                ElevatedButton(
                  onPressed: () => _validateManualKey(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warmBrown,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Validate',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // License key status message removed
        ],
      ),
    );
  }

  Future<void> _validateManualKey() async {
    final key = _licenseKeyController.text;

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a license key.'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
      return;
    }

    try {
      final licenseProvider =
          Provider.of<LicenseProvider>(context, listen: false);
      bool success = false;

      // Determine key type and validate accordingly
      if (key.startsWith('ij_life_')) {
        success = await licenseProvider.validateLifetimeKey(key);
      } else if (key.startsWith('ij_sub_')) {
        success = await licenseProvider.validateSubscriptionKey(key);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Invalid key format. Must start with ij_life_ or ij_sub_'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
        return;
      }

      if (success) {
        _licenseKeyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ License key validated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Invalid license key. Please check and try again.'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error validating license key: $e'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
    }
  }

  /// Toggle license key visibility
  void _toggleLicenseKeyVisibility() {
    setState(() {
      _showLicenseKey = !_showLicenseKey;
    });
  }

  /// Clear all stored license keys
  Future<void> _clearAllStoredKeys() async {
    try {
      debugPrint('🧹 Settings: Clearing all license keys...');

      // Clear local UI state first
      setState(() {
        _currentLicenseKey = null;
        _showLicenseKey = false;
        _licenseKeyController.clear();
      });

      // Clear all license data through the provider
      // (This will clear storage and set invalid state)
      final provider = Provider.of<LicenseProvider>(context, listen: false);
      await provider.clearLicenseData();

      debugPrint('✅ All license keys cleared - navigating to license screen');

      // Navigate back to the license check wrapper (root)
      // This ensures the Consumer pattern works correctly
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      debugPrint('❌ Error clearing keys: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing keys: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }

  /// TEMP: Input and validate manual key
  Future<void> _inputAndValidateKey() async {
    final keyController = TextEditingController();

    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBeige,
        title: Text(
          'Enter License Key',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: keyController,
          decoration: InputDecoration(
            hintText: 'ij_sub_... or ij_life_...',
            border: OutlineInputBorder(),
          ),
          style: TextStyle(fontFamily: 'JetBrainsMono'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(keyController.text),
            child: Text('Validate'),
          ),
        ],
      ),
    );

    if (key == null || key.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Store the key in SharedPreferences
      if (key.startsWith('ij_life_')) {
        await prefs.setString('license_key', key);
      } else if (key.startsWith('ij_sub_')) {
        await prefs.setString('subscription_key', key);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Invalid key format. Must start with ij_life_ or ij_sub_'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
        return;
      }

      // Update local state
      setState(() {
        _currentLicenseKey = key;
        _licenseKeyController.text = key;
      });

      // Validate the key through license provider
      final provider = Provider.of<LicenseProvider>(context, listen: false);
      bool isValid = false;

      if (key.startsWith('ij_life_')) {
        isValid = await provider.validateLifetimeKey(key);
      } else if (key.startsWith('ij_sub_')) {
        isValid = await provider.validateSubscriptionKey(key);
      }

      if (isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ License key validated and stored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Key stored but validation failed - may be invalid or expired'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting key: $e'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
    }
  }

  /// License Management buttons
  Widget _buildLicenseManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'License Management',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _inputAndValidateKey(),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.creamBeige,
                  side: BorderSide(color: AppTheme.warmBrown.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Add License Key',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: AppTheme.warmBrown,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _clearAllStoredKeys(),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.warningRed.withOpacity(0.1),
                  side: BorderSide(color: AppTheme.warningRed.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Clear All Keys',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: AppTheme.warningRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Independent login button (always visible)
  Widget _buildIndependentLoginButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _openUserPortal(),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppTheme.creamBeige,
              side: BorderSide(color: AppTheme.warmBrown.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login, size: 16, color: AppTheme.warmBrown),
                SizedBox(width: 8),
                Text(
                  'Access User Portal',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
                    color: AppTheme.warmBrown,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'View subscription details and retrieve license keys',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11.0,
            color: AppTheme.mediumGray,
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseActions(LicenseProvider licenseProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No trial - license key required from start

        // Expired license: Upgrade button
        if (licenseProvider.needsLicense) ...[
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openUpgradeOptions(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warmBrown,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upgrade, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Activate License',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14.0,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Lifetime users: No additional buttons needed (they have permanent access)
        if (licenseProvider.isLifetime) ...[
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  'Lifetime access activated',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Emergency: Clear invalid key button (for debugging)
        if (!licenseProvider.isValid) ...[
          SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _clearInvalidKey(licenseProvider),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppTheme.warningRed.withOpacity(0.1),
              side: BorderSide(color: AppTheme.warningRed.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, size: 14, color: AppTheme.warningRed),
                SizedBox(width: 6),
                Text(
                  'Clear Invalid Key',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: AppTheme.warningRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Open user portal in browser - simple and reliable!
  Future<void> _openUserPortal() async {
    const portalUrl = 'https://pay.islajournal.app/p/login/cNieVc50A7yGfkv4BQ73G00';

    // Open in browser directly
    await BrowserService.openUrlWithConfirmation(
      context,
      portalUrl,
      title: 'Open Customer Portal',
    );

    // Show helpful message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Portal opened in browser! Your license key should be visible there.'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 6),
      ),
    );
  }

  Future<void> _openUpgradeOptions() async {
    // Show upgrade options dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.creamBeige,
          title: Text(
            'Upgrade Your License',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w600,
              color: AppTheme.warmBrown,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Monthly Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openPaymentLink('https://pay.islajournal.app/b/dRmaEWct2cT03BN6JY73G01', 'Monthly');
                  },
                  child: Text('Monthly - \$7'),
                ),
              ),
              SizedBox(height: 8),
              // Annual Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openPaymentLink('https://pay.islajournal.app/b/7sY28qakUg5cfkv2tI73G02', 'Annual');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warmBrown,
                  ),
                  child: Text('Annual - \$49 (Save \$35!)'),
                ),
              ),
              SizedBox(height: 8),
              // Lifetime Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openPaymentLink('https://pay.islajournal.app/b/cNieVc50A7yGfkv4BQ73G00', 'Lifetime');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkerBrown,
                  ),
                  child: Text('Lifetime - \$99 (Never Pay Again!)'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.mediumGray),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPaymentLink(String url, String planName) async {
    await BrowserService.openUrlWithConfirmation(
      context,
      url,
      title: 'Upgrade to $planName',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$planName upgrade page opened in browser!'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 5),
      ),
    );
  }

  /// AI Assistant section with Ollama status
  Widget _buildAISection(AIProvider aiProvider) {
    return Consumer<AIProvider>(
      builder: (context, aiProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple AI status header
            Text(
              'AI Assistant',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            SizedBox(height: 12),
            
            // Ollama status card
            _buildOllamaStatusCard(aiProvider),
          ],
        );
      },
    );
  }

  /// Build Ollama status card with visual indicators
  Widget _buildOllamaStatusCard(AIProvider aiProvider) {
    final hasModel = aiProvider.currentModelId != null;
    final isReady = hasModel && aiProvider.isModelLoaded;
    
    // Check if Ollama is installed by seeing if we have any available models
    final hasAvailableModels = aiProvider.modelStatuses.values.any((status) => 
      status == ModelStatus.downloaded || status == ModelStatus.loaded || status == ModelStatus.error);
    final isOllamaInstalled = hasAvailableModels || hasModel;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main status card
        Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.creamBeige,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.mediumGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Status Header
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: AppTheme.warmBrown,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'AI Assistant',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              Spacer(),
              // Status indicator
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isReady ? Colors.green : AppTheme.mediumGray,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                isReady ? 'Ready' : 'Not Ready',
                style: TextStyle(
                  fontSize: 12,
                  color: isReady ? Colors.green : AppTheme.mediumGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
              // Clean current model display with edit button
              _buildCleanModelDisplay(aiProvider, isOllamaInstalled),
              
              SizedBox(height: 12),
              
              // Quick info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkerCream.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isReady 
                    ? '✅ AI is ready for questions and writing assistance (works offline)'
                    : '💡 Install Ollama and download a model to enable AI features',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build clean model display with edit button
  Widget _buildCleanModelDisplay(AIProvider aiProvider, bool isOllamaInstalled) {
    final currentModel = aiProvider.currentModelId;
    
    if (!isOllamaInstalled) {
      // Show Ollama download if not installed
      return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Model:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
              SizedBox(height: 4),
              Text(
            'No model selected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkText,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => BrowserService.openUrl('https://ollama.ai/download'),
                  icon: Icon(Icons.download, size: 16),
                  label: Text('Download Ollama'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warmBrown,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Model:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
              SizedBox(height: 4),
              if (currentModel != null) ...[
                Text(
                  aiProvider.availableModels[currentModel]?.name ?? currentModel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkText,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
                if (aiProvider.availableModels[currentModel] != null) ...[
                  SizedBox(height: 2),
                  Text(
                    '${aiProvider.availableModels[currentModel]!.sizeGB}GB • Quality: ${aiProvider.availableModels[currentModel]!.qualityScore}/10',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  'No model loaded',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mediumGray,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ],
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showModelSelectionDialog(aiProvider),
          icon: Icon(Icons.edit, size: 16),
          label: Text('Edit Models'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warmBrown,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }



  /// Show comprehensive model management dialog
  void _showModelSelectionDialog(AIProvider aiProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final allModels = aiProvider.availableModels.entries.toList();
            final recommendedModels = aiProvider.getRecommendedModels();
            
            // Group models by status
            final downloadedModels = allModels.where((entry) => 
                aiProvider.modelStatuses[entry.key] == ModelStatus.downloaded || 
                aiProvider.modelStatuses[entry.key] == ModelStatus.loaded).toList();
            final notDownloadedModels = allModels.where((entry) => 
                aiProvider.modelStatuses[entry.key] == ModelStatus.notDownloaded).toList();
            final downloadingModels = allModels.where((entry) => 
                aiProvider.modelStatuses[entry.key] == ModelStatus.downloading).toList();

            return AlertDialog(
              title: Text(
                'Manage AI Models',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Downloaded models section
                      if (downloadedModels.isNotEmpty) ...[
                        Text(
                          'Downloaded Models',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...downloadedModels.map((entry) => _buildModelListTile(
                          entry.value, 
                          aiProvider, 
                          recommendedModels.contains(entry.value),
                          setState,
                        )),
                        SizedBox(height: 16),
                      ],
                      
                      // Currently downloading models
                      if (downloadingModels.isNotEmpty) ...[
                        Text(
                          'Downloading',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...downloadingModels.map((entry) => _buildModelListTile(
                          entry.value, 
                          aiProvider, 
                          recommendedModels.contains(entry.value),
                          setState,
                        )),
                        SizedBox(height: 16),
                      ],
                      
                      // Available for download models
                      if (notDownloadedModels.isNotEmpty) ...[
                        Text(
                          'Available for Download',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mediumGray,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...notDownloadedModels.map((entry) => _buildModelListTile(
                          entry.value, 
                          aiProvider, 
                          recommendedModels.contains(entry.value),
                          setState,
                        )),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Build individual model list tile for the dialog
  Widget _buildModelListTile(DeviceOptimizedModel model, AIProvider aiProvider, bool isRecommended, StateSetter setState) {
    final status = aiProvider.modelStatuses[model.id] ?? ModelStatus.notDownloaded;
    final isCurrentModel = aiProvider.currentModelId == model.id;
    final canDownload = model.minRAMGB <= aiProvider.deviceRAMGB;
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                model.name,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isRecommended) ...[
          Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                  color: AppTheme.warmBrown,
                  borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
                  'RECOMMENDED',
              style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            if (!canDownload) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NEEDS ${model.minRAMGB}GB RAM',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${model.sizeGB}GB • ${model.description}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.mediumGray,
              ),
            ),
            if (status == ModelStatus.downloading) ...[
              SizedBox(height: 4),
              LinearProgressIndicator(
                backgroundColor: AppTheme.mediumGray.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
              ),
            ],
          ],
        ),
        leading: _buildModelListIcon(status, isCurrentModel),
        trailing: _buildModelListActions(model, status, aiProvider, canDownload, setState),
        tileColor: isCurrentModel ? AppTheme.warmBrown.withOpacity(0.1) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Build icon for model list tile
  Widget _buildModelListIcon(ModelStatus status, bool isCurrentModel) {
    switch (status) {
      case ModelStatus.loaded:
        return Icon(Icons.radio_button_checked, color: Colors.green);
      case ModelStatus.downloaded:
        return Icon(Icons.radio_button_unchecked, color: AppTheme.warmBrown);
      case ModelStatus.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
          ),
        );
      case ModelStatus.error:
        return Icon(Icons.error, color: Colors.red);
      default:
        return Icon(Icons.download, color: AppTheme.mediumGray);
    }
  }

  /// Build action buttons for model list tile
  Widget _buildModelListActions(DeviceOptimizedModel model, ModelStatus status, AIProvider aiProvider, bool canDownload, StateSetter setState) {
    switch (status) {
      case ModelStatus.notDownloaded:
        return ElevatedButton(
          onPressed: canDownload ? () async {
            setState(() {}); // Update UI immediately
            await _downloadModel(model.id, aiProvider);
            setState(() {}); // Update UI after download
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warmBrown,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size(80, 32),
          ),
          child: Text(
            'Download',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        );
      
      case ModelStatus.downloaded:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _switchToModel(model.id, aiProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warmBrown,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size(60, 32),
              ),
              child: Text(
                'Use',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 4),
            IconButton(
              onPressed: () => _showDeleteConfirmationInDialog(model, aiProvider, setState),
              icon: Icon(Icons.delete, size: 18, color: Colors.red),
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        );
      
      case ModelStatus.loaded:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                'Active',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 4),
            IconButton(
              onPressed: () => _showDeleteConfirmationInDialog(model, aiProvider, setState),
              icon: Icon(Icons.delete, size: 18, color: Colors.red),
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        );
      
      case ModelStatus.downloading:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            'Downloading...',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.mediumGray,
            ),
          ),
        );
      
      case ModelStatus.error:
        return ElevatedButton(
          onPressed: canDownload ? () async {
            setState(() {}); // Update UI immediately
            await _downloadModel(model.id, aiProvider);
            setState(() {}); // Update UI after download
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size(80, 32),
          ),
          child: Text(
            'Retry',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        );
    }
  }

  /// Show delete confirmation within the dialog
  void _showDeleteConfirmationInDialog(DeviceOptimizedModel model, AIProvider aiProvider, StateSetter setState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Model',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${model.name}"?\n\nThis will free up ${model.sizeGB}GB of storage but you\'ll need to download it again to use it.',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.mediumGray),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close confirmation dialog
                await _deleteModel(model.id, aiProvider);
                setState(() {}); // Update the main dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentModelStatus(AIProvider aiProvider) {
    final currentModel = aiProvider.currentModelId != null
        ? aiProvider.availableModels[aiProvider.currentModelId!]
        : null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.mediumGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.smart_toy,
                size: 20,
                color: AppTheme.warmBrown,
              ),
              SizedBox(width: 8),
              Text(
                'Current Model',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (currentModel != null) ...[
            Text(
              currentModel.name,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkText,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${currentModel.quantization} • ${currentModel.sizeGB}GB • Quality: ${currentModel.qualityScore}/10',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11.0,
                color: AppTheme.mediumGray,
              ),
            ),
            SizedBox(height: 8),
            Text(
              currentModel.description,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11.0,
                color: AppTheme.mediumGray,
              ),
            ),
            if (aiProvider.isModelLoaded) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Model loaded and ready',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11.0,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            Text(
              'No model loaded',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13.0,
                color: AppTheme.mediumGray,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Download and load a model to use AI features',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11.0,
                color: AppTheme.mediumGray,
              ),
            ),
          ],
        ],
      ),
    );
  }







  Future<void> _downloadModel(String modelId, AIProvider aiProvider) async {
    try {
      await aiProvider.downloadModel(modelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Model downloaded successfully! Click "Load" to activate.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadModel(String modelId, AIProvider aiProvider) async {
    try {
      await aiProvider.loadModel(modelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model loaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _switchToModel(String modelId, AIProvider aiProvider) async {
    try {
      // If there's a current model loaded, unload it first
      if (aiProvider.currentModelId != null && aiProvider.isModelLoaded) {
        await aiProvider.unloadModel();
      }
      
      // Load the new model
      await aiProvider.loadModel(modelId);
      
      if (mounted) {
        final modelName = aiProvider.availableModels[modelId]?.name ?? modelId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $modelName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteModel(String modelId, AIProvider aiProvider) async {
    try {
      // If this model is currently loaded, unload it first
      if (aiProvider.currentModelId == modelId && aiProvider.isModelLoaded) {
        await aiProvider.unloadModel();
      }
      
      // Delete the model
      await aiProvider.deleteModel(modelId);
      
      if (mounted) {
        final modelName = aiProvider.availableModels[modelId]?.name ?? modelId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $modelName'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unloadModel(AIProvider aiProvider) async {
    try {
      await aiProvider.unloadModel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model unloaded'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unload model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteModelDialog(String modelId, AIProvider aiProvider) {
    final model = aiProvider.availableModels[modelId];
    if (model == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Model',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${model.name}"?\n\nThis will free up ${model.sizeGB}GB of storage but you\'ll need to download it again to use it.',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13.0,
                  color: AppTheme.mediumGray,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await aiProvider.deleteModel(modelId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Model deleted'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete model: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13.0,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
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
      debugPrint('Error loading token usage: $e');
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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
      final journalProvider =
          Provider.of<JournalProvider>(context, listen: false);
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
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
      final journalProvider =
          Provider.of<JournalProvider>(context, listen: false);
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
            'downloaded models: ${aiProvider.modelStatuses.values.where((status) => status == ModelStatus.downloaded || status == ModelStatus.loaded).length}',
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

  /// Clear invalid stored key
  Future<void> _clearInvalidKey(LicenseProvider licenseProvider) async {
    try {
      debugPrint('🧹 Clearing invalid license key...');
      await licenseProvider.clearLicenseData();
      debugPrint('✅ Invalid key cleared - navigating to license screen');

      // Navigate back to the license check wrapper (root)
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      debugPrint('❌ Error clearing invalid key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing key: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }

  /// Build Ollama setup section with download link
  Widget _buildOllamaSetupSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.mediumGray.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.download_rounded,
                color: AppTheme.warmBrown,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Ollama AI Engine',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
                         Text(
                 Platform.isWindows 
                   ? 'For Windows AI features, install Ollama - a separate AI engine that prevents crashes.'
                   : 'Install Ollama for faster, more stable AI with native Apple Silicon support.',
                 style: TextStyle(
                   fontSize: 14,
                   color: AppTheme.mediumGray,
                   height: 1.4,
                 ),
               ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _downloadOllama,
                  icon: Icon(Icons.open_in_browser),
                  label: Text('Download Ollama'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warmBrown,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showOllamaSetupGuide,
                  icon: Icon(Icons.help_outline),
                  label: Text('Setup Guide'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warmBrown,
                    side: BorderSide(color: AppTheme.warmBrown),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Open Ollama download page in browser
  Future<void> _downloadOllama() async {
    const url = 'https://ollama.ai/download';
    try {
      await BrowserService.openUrl(url);
      
      // Show helpful message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🌐 Opening Ollama download page...'),
            backgroundColor: AppTheme.warmBrown,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Could not open browser: $e'),
            backgroundColor: AppTheme.warningRed,
          ),
        );
      }
    }
  }

  /// Show Ollama setup guide dialog
  void _showOllamaSetupGuide() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.settings, color: AppTheme.warmBrown),
              SizedBox(width: 8),
              Text('Ollama Setup Guide'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '📥 Quick Setup (5 minutes):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),
                _buildSetupStep('1', 'Download & install Ollama from the link above'),
                _buildSetupStep('2', 'Open Command Prompt and run:\n   ollama pull llama3.2:3b'),
                _buildSetupStep('3', 'Test the connection using the button below'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray,
                    borderRadius: BorderRadius.circular(6),
                  ),
                                         child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             '✅ Benefits:',
                             style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warmBrown),
                           ),
                           SizedBox(height: 4),
                           Text(Platform.isWindows 
                             ? '• No more Windows crashes\n• Faster AI responses\n• Works offline\n• Easy to update'
                             : '• Native Apple Silicon support\n• Faster than fllama\n• Works offline\n• Easy to update'),
                         ],
                       ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Got it!', style: TextStyle(color: AppTheme.warmBrown)),
            ),
          ],
        );
      },
    );
  }

  /// Build a setup step widget
  Widget _buildSetupStep(String number, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.warmBrown,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 14, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }


}
