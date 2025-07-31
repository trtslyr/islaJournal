import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/ai_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/license_provider.dart';
import '../widgets/license_dialog.dart';
import '../services/ai_service.dart';
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
  bool _isModelsExpanded = false; // AI Models section collapsed by default

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
          print(
              '📱 Clamped token usage from ${savedTokens.toInt()} to ${clampedTokens.toInt()} for efficiency');
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

  /// Load stored license key from secure storage
  Future<void> _loadStoredLicenseKey() async {
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
        licenseKey = prefs.getString('license_key') ??
            prefs.getString('subscription_key');
      }

      if (licenseKey != null && mounted) {
        setState(() {
          _currentLicenseKey = licenseKey;
          _showLicenseKey = false; // Hide by default
          _licenseKeyController.text =
              licenseKey!; // Use null assertion since we checked above
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
        ],
      ),
    );
  }

  Color _getLicenseCardColor(LicenseProvider licenseProvider) {
    if (licenseProvider.isLifetime) return AppTheme.warmBrown.withOpacity(0.1);
    if (licenseProvider.isSubscription)
      return AppTheme.darkerBrown.withOpacity(0.1);
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
        Container(
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
          Container(
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

  // Open user portal (Stripe customer portal) inline
  Future<void> _openUserPortal() async {
    try {
      const portalUrl =
          'https://pay.islajournal.app/p/login/cNieVc50A7yGfkv4BQ73G00';

      // Open portal in inline webview dialog
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CustomerPortalDialog(
          portalUrl: portalUrl,
        ),
      );

      if (result == true) {
        // User completed login and accessed their key, refresh license status
        final provider = Provider.of<LicenseProvider>(context, listen: false);
        await provider.checkLicense();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Portal accessed! Your license key should be visible there.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening user portal: $e'),
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

  /// AI Models section with model management
  Widget _buildAISection(AIProvider aiProvider) {
    return Consumer<AIProvider>(
      builder: (context, aiProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsible header
            InkWell(
              onTap: () {
                setState(() {
                  _isModelsExpanded = !_isModelsExpanded;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _isModelsExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.darkText,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Models',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                    // Show active model indicator
                    if (!_isModelsExpanded && aiProvider.isModelLoaded) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10.0,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Expandable content
            AnimatedCrossFade(
              crossFadeState: _isModelsExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: Duration(milliseconds: 200),
              firstChild: SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'Device: ${aiProvider.deviceType ?? 'Unknown'} (${aiProvider.deviceRAMGB}GB RAM)',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Current model status
                  _buildCurrentModelStatus(aiProvider),
                  SizedBox(height: 24),

                  // Available models
                  _buildAvailableModelsList(aiProvider),
                  SizedBox(height: 16),

                  // Storage info
                  _buildStorageInfo(aiProvider),
                ],
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

  Widget _buildAvailableModelsList(AIProvider aiProvider) {
    final recommendedModels = aiProvider.getRecommendedModels();
    final allModels = aiProvider.availableModels.values.toList();

    // Sort models by RAM requirement (ascending)
    allModels.sort((a, b) => a.minRAMGB.compareTo(b.minRAMGB));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Models',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: AppTheme.darkText,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Download, load, and delete AI models. Only keep what you need to save storage.',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12.0,
            color: AppTheme.mediumGray,
          ),
        ),
        SizedBox(height: 12),

        // Individual model cards with buttons
        ...allModels.map((model) {
          final isRecommended = recommendedModels.contains(model);
          return _buildModelCard(model, aiProvider,
              isRecommended: isRecommended);
        }).toList(),

        SizedBox(height: 16),
      ],
    );
  }

  void _handleModelAction(
      DeviceOptimizedModel model, ModelStatus status, AIProvider aiProvider) {
    switch (status) {
      case ModelStatus.notDownloaded:
        _downloadModel(model.id, aiProvider);
        break;
      case ModelStatus.downloaded:
        _loadModel(model.id, aiProvider);
        break;
      case ModelStatus.loaded:
        _unloadModel(aiProvider);
        break;
      case ModelStatus.error:
        _downloadModel(model.id, aiProvider); // Retry
        break;
      default:
        break;
    }
  }

  void _handleDeleteModel(String modelId, AIProvider aiProvider) {
    _showDeleteModelDialog(modelId, aiProvider);
  }

  String _getActionButtonText(ModelStatus status) {
    switch (status) {
      case ModelStatus.notDownloaded:
        return 'Download';
      case ModelStatus.downloading:
        return 'Downloading...';
      case ModelStatus.downloaded:
        return 'Load Model';
      case ModelStatus.loaded:
        return 'Unload';
      case ModelStatus.error:
        return 'Retry Download';
    }
  }

  Color _getActionButtonColor(ModelStatus status) {
    switch (status) {
      case ModelStatus.notDownloaded:
        return AppTheme.warmBrown;
      case ModelStatus.downloading:
        return AppTheme.mediumGray;
      case ModelStatus.downloaded:
        return Colors.green;
      case ModelStatus.loaded:
        return Colors.orange;
      case ModelStatus.error:
        return AppTheme.warningRed;
    }
  }

  Color _getStatusColor(ModelStatus status) {
    switch (status) {
      case ModelStatus.notDownloaded:
        return AppTheme.mediumGray;
      case ModelStatus.downloading:
        return Colors.blue;
      case ModelStatus.downloaded:
        return Colors.orange;
      case ModelStatus.loaded:
        return Colors.green;
      case ModelStatus.error:
        return AppTheme.warningRed;
    }
  }

  String _getStatusText(ModelStatus status) {
    switch (status) {
      case ModelStatus.notDownloaded:
        return 'NOT DOWNLOADED';
      case ModelStatus.downloading:
        return 'DOWNLOADING';
      case ModelStatus.downloaded:
        return 'READY TO LOAD';
      case ModelStatus.loaded:
        return 'LOADED';
      case ModelStatus.error:
        return 'ERROR';
    }
  }

  Widget _buildModelCard(DeviceOptimizedModel model, AIProvider aiProvider,
      {required bool isRecommended}) {
    final status =
        aiProvider.modelStatuses[model.id] ?? ModelStatus.notDownloaded;
    final canDownload = model.minRAMGB <= aiProvider.deviceRAMGB;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRecommended && model.isRecommended
              ? AppTheme.warmBrown.withOpacity(0.3)
              : AppTheme.mediumGray.withOpacity(0.3),
          width: isRecommended && model.isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          model.name,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.darkText,
                          ),
                        ),
                        if (model.isRecommended) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.warmBrown,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 8.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${model.quantization} • ${model.sizeGB}GB • Quality ${model.qualityScore}/10',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11.0,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              _buildModelStatusIndicator(status),
            ],
          ),
          SizedBox(height: 8),
          Text(
            model.description,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11.0,
              color: AppTheme.mediumGray,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Optimized for: ${model.optimizedFor.join(', ')}',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10.0,
              color: AppTheme.mediumGray,
            ),
          ),
          if (!canDownload) ...[
            SizedBox(height: 8),
            Text(
              '⚠️ Requires ${model.minRAMGB}GB RAM (you have ${aiProvider.deviceRAMGB}GB)',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10.0,
                color: Colors.orange,
              ),
            ),
          ],
          SizedBox(height: 12),
          _buildModelControls(model, status, aiProvider, canDownload),
        ],
      ),
    );
  }

  Widget _buildModelControls(DeviceOptimizedModel model, ModelStatus status,
      AIProvider aiProvider, bool canDownload) {
    final downloadProgress = aiProvider.downloadProgress;

    // Show progress bar only if downloading AND progress is valid
    if (status == ModelStatus.downloading &&
        downloadProgress != null &&
        downloadProgress.total > 0) {
      return _buildDownloadProgress(downloadProgress);
    }

    return Row(
      children: [
        if (status == ModelStatus.notDownloaded && canDownload) ...[
          ElevatedButton(
            onPressed: () => _downloadModel(model.id, aiProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warmBrown,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Download',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ] else if (status == ModelStatus.downloaded) ...[
          ElevatedButton(
            onPressed: () => _loadModel(model.id, aiProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Load',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          _buildDeleteModelButton(model.id, aiProvider),
        ] else if (status == ModelStatus.loaded) ...[
          ElevatedButton(
            onPressed: () => _unloadModel(aiProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stop, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Unload',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          _buildDeleteModelButton(model.id, aiProvider),
        ] else if (status == ModelStatus.error) ...[
          ElevatedButton(
            onPressed:
                canDownload ? () => _downloadModel(model.id, aiProvider) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!canDownload && status == ModelStatus.notDownloaded) ...[
          Text(
            'Insufficient RAM',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11.0,
              color: Colors.orange,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelStatusIndicator(ModelStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case ModelStatus.downloaded:
        color = Colors.blue;
        icon = Icons.download_done;
        break;
      case ModelStatus.loaded:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ModelStatus.downloading:
        color = Colors.orange;
        icon = Icons.downloading;
        break;
      case ModelStatus.error:
        color = Colors.red;
        icon = Icons.error;
        break;
      case ModelStatus.notDownloaded:
      default:
        color = AppTheme.mediumGray;
        icon = Icons.cloud_download;
        break;
    }

    return Icon(icon, color: color, size: 20);
  }

  Widget _buildDownloadProgress(DownloadProgress progress) {
    final isComplete = progress.percentage >= 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress.percentage / 100,
                backgroundColor: AppTheme.mediumGray.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? Colors.green : AppTheme.warmBrown),
              ),
            ),
            SizedBox(width: 8),
            Text(
              '${progress.percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11.0,
                color: isComplete ? Colors.green : AppTheme.darkText,
                fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          isComplete
              ? 'Download complete! Preparing...'
              : '${progress.speed.toStringAsFixed(1)} MB/s • ${progress.remainingTime}s remaining',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10.0,
            color: isComplete ? Colors.green : AppTheme.mediumGray,
            fontWeight: isComplete ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteModelButton(String modelId, AIProvider aiProvider) {
    return OutlinedButton(
      onPressed: () => _showDeleteModelDialog(modelId, aiProvider),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.red.withOpacity(0.5)),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete, size: 14, color: Colors.red),
          SizedBox(width: 4),
          Text(
            'Delete',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfo(AIProvider aiProvider) {
    return FutureBuilder<String>(
      future: aiProvider.getStorageUsage(),
      builder: (context, snapshot) {
        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.darkerCream.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.mediumGray.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.storage, size: 16, color: AppTheme.mediumGray),
              SizedBox(width: 8),
              Text(
                'Storage used: ${snapshot.data ?? 'Calculating...'}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11.0,
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
          ),
        );
      },
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
}

class _CustomerPortalDialog extends StatefulWidget {
  final String portalUrl;

  const _CustomerPortalDialog({
    Key? key,
    required this.portalUrl,
  }) : super(key: key);

  @override
  State<_CustomerPortalDialog> createState() => _CustomerPortalDialogState();
}

class _CustomerPortalDialogState extends State<_CustomerPortalDialog> {
  late final WebViewController controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.portalUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        child: Column(
          children: [
            // Header bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkerCream,
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.mediumGray.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  Text(
                    'Customer Portal',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warmBrown,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 14.0,
                        color: AppTheme.warmBrown,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 14.0,
                        color: AppTheme.warmBrown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // WebView content
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: controller),
                  if (_isLoading)
                    Container(
                      color: AppTheme.creamBeige,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.warmBrown),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading customer portal...',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 14.0,
                                color: AppTheme.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
