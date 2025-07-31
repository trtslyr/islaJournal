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
        licenseKey = prefs.getString('license_key') ?? prefs.getString('subscription_key');
      }
      
      if (licenseKey != null && mounted) {
        setState(() {
          _currentLicenseKey = licenseKey;
          _showLicenseKey = false; // Hide by default  
          _licenseKeyController.text = licenseKey!; // Use null assertion since we checked above
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
          
          // Action buttons based on license type
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
                  readOnly: hasValidKey, // Make read-only when license is active
                  obscureText: !_showLicenseKey && hasValidKey,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: hasValidKey ? AppTheme.darkText : AppTheme.darkText,
                  ),
                  decoration: InputDecoration(
                    hintText: hasValidKey ? null : 'Enter your license key (ij_life_... or ij_sub_...)',
                    hintStyle: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      color: AppTheme.mediumGray,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: hasValidKey ? Colors.green : AppTheme.mediumGray),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: hasValidKey ? Colors.green : AppTheme.mediumGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: hasValidKey ? Colors.green : AppTheme.warmBrown),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: hasValidKey ? Colors.green.withOpacity(0.1) : Colors.white,
                  ),
                  onChanged: hasValidKey ? null : (value) {
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          if (hasValidKey) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  'License key active and stored securely',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
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
      final licenseProvider = Provider.of<LicenseProvider>(context, listen: false);
      bool success = false;
      
      // Determine key type and validate accordingly
      if (key.startsWith('ij_life_')) {
        success = await licenseProvider.validateLifetimeKey(key);
      } else if (key.startsWith('ij_sub_')) {
        success = await licenseProvider.validateSubscriptionKey(key);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid key format. Must start with ij_life_ or ij_sub_'),
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

  /// TEMP: Clear all stored license keys (comprehensive version)
  Future<void> _clearAllStoredKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear ALL license-related keys from SharedPreferences
      // These are the actual storage keys used by LicenseService
      await prefs.remove('license_key');           // Lifetime keys
      await prefs.remove('subscription_key');      // Subscription keys  
      await prefs.remove('license_status');        // Cached license status
      await prefs.remove('trial_start');           // Trial start time
      await prefs.remove('device_id');             // Device ID
      
      // Also clear any legacy keys that might exist
      await prefs.remove('license_type');
      await prefs.remove('license_valid');
      await prefs.remove('trial_start_time');
      
      // Try to clear secure storage but ignore errors (expected to fail on debug builds)
      try {
        final storage = FlutterSecureStorage();
        await storage.deleteAll(); // Clear everything from keychain
      } catch (secureStorageError) {
        // Expected to fail - ignore it
        print('Secure storage clear failed (expected on debug builds): $secureStorageError');
      }
      
      // Clear local state
      setState(() {
        _currentLicenseKey = null;
        _showLicenseKey = false;
        _licenseKeyController.clear();
      });
      
      // Force complete license provider reset
      final provider = Provider.of<LicenseProvider>(context, listen: false);
      
      // Reset the provider's internal state
      provider.clearLicenseData();
      
      // Force a fresh license check (should start new trial)
      await provider.checkLicense();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ All license data completely cleared! Starting fresh trial.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing keys: $e'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
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
            content: Text('❌ Invalid key format. Must start with ij_life_ or ij_sub_'),
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
            content: Text('❌ Key stored but validation failed - may be invalid or expired'),
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

  Widget _buildLicenseActions(LicenseProvider licenseProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subscription users: Login button to access portal
        if (licenseProvider.isSubscription) ...[
            ElevatedButton(
            onPressed: () => _openUserPortal(),
              style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warmBrown,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Login to User Portal',
                  style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '💡 Access your subscription details and license key',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.mediumGray,
              ),
            ),
          ],
        
        // Trial users: Purchase options
        if (licenseProvider.isTrial) ...[
          Text(
            'Purchase Options:',
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
                child: ElevatedButton(
            onPressed: () => _openUpgradeOptions(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkerBrown,
                    padding: const EdgeInsets.symmetric(vertical: 12),
            ),
                  child: Text(
                    'Monthly (\$7)',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _openUpgradeOptions(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkerBrown,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Annual (\$49)',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _openUpgradeOptions(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warmBrown,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Lifetime (\$99)',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        
        // TEMP: Clear all keys button (for debugging)
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _clearAllStoredKeys(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            '🗑️ CLEAR ALL STORED KEYS',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
                 // TEMP: Input manual key button
         SizedBox(height: 8),
         ElevatedButton(
           onPressed: () => _inputAndValidateKey(),
           style: ElevatedButton.styleFrom(
             backgroundColor: Colors.blue,
             padding: const EdgeInsets.symmetric(vertical: 12),
           ),
           child: Text(
             '⌨️ INPUT & VALIDATE KEY',
             style: TextStyle(
               fontFamily: 'JetBrainsMono',
               fontSize: 14.0,
               color: Colors.white,
               fontWeight: FontWeight.w600,
             ),
           ),
         ),
        
        // Expired license: Upgrade button
        if (licenseProvider.needsLicense) ...[
          ElevatedButton(
            onPressed: () => _openUpgradeOptions(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningRed,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text(
              'Activate License',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
                    color: Colors.white,
              ),
                ),
              ],
            ),
          ),
        ],
        
        // Lifetime users: No additional buttons needed (they have permanent access)
        if (licenseProvider.isLifetime) ...[
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.verified, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  'Lifetime access activated',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
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
        ElevatedButton(
            onPressed: () => _clearInvalidKey(licenseProvider),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Clear Invalid Stored Key',
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
      ],
    );
  }

  // Open user portal (Stripe customer portal) inline
  Future<void> _openUserPortal() async {
    try {
      const portalUrl = 'https://pay.islajournal.app/p/login/cNieVc50A7yGfkv4BQ73G00';
      
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
            content: Text('✅ Portal accessed! Your license key should be visible there.'),
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

  // Clear invalid stored key (emergency fix)
  Future<void> _clearInvalidKey(LicenseProvider licenseProvider) async {
    try {
      await licenseProvider.clearLicenseData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Invalid key cleared! You can now enter your correct key.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing key: $e'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
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
                border: Border(bottom: BorderSide(color: AppTheme.mediumGray.withOpacity(0.3))),
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
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
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