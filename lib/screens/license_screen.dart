import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/license_provider.dart';
import '../core/theme/app_theme.dart';
import '../services/browser_service.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final TextEditingController _keyController = TextEditingController();
  
  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBeige,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              padding: EdgeInsets.all(24),
              constraints: BoxConstraints(maxWidth: 500),
              child: Consumer<LicenseProvider>(
                builder: (context, license, child) {
                  if (false) { // Loading state removed
                    return _buildLoadingView();
                  }
                  
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 20),
                      _buildHeader(),
                      SizedBox(height: 24),
                      _buildLifetimeSection(),
                      SizedBox(height: 20),
                      _buildOrDivider(),
                      SizedBox(height: 20),
                      _buildLoginSection(),
                      SizedBox(height: 20),
                      _buildSubscriptionSection(),
                      SizedBox(height: 40), // Extra bottom padding
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'isla journal',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'activate your license',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16,
            color: AppTheme.mediumGray,
          ),
        ),
      ],
    );
  }
  
  // Trial status removed - license key required from start
  
  Widget _buildLifetimeSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars, color: AppTheme.warmBrown),
                SizedBox(width: 8),
                Text(
                  'Enter License Key',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
                                  'Enter your license key (lifetime or subscription)',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: AppTheme.mediumGray,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                hintText: 'ij_life_abc123...',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                                      onPressed: _validateLicenseKey,
                                      child: Text('Activate License'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.mediumGray)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              color: AppTheme.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.mediumGray)),
      ],
    );
  }

  Widget _buildLoginSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        border: Border.all(color: AppTheme.mediumGray.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.login,
            size: 32,
            color: AppTheme.warmBrown,
          ),
          SizedBox(height: 16),
          Text(
            'Already Purchased?',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Access your license key from your purchase',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openCustomerPortal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warmBrown,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_browser, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Login to Access Your Key',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            '💡 Your license key will be visible in your account',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _openCustomerPortal() async {
    const portalUrl = 'https://pay.islajournal.app/p/login/cNieVc50A7yGfkv4BQ73G00';
    
    // Open in browser directly - simpler and more reliable!
    await BrowserService.openUrlWithConfirmation(
      context, 
      portalUrl,
      title: 'Open Customer Portal',
    );
    
    // Show helpful message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Portal opened in browser! Copy your license key from there and enter it above.'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 8),
      ),
    );
  }
  
  Widget _buildSubscriptionSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.subscriptions, color: AppTheme.warmBrown),
                SizedBox(width: 8),
                Text(
                  'Subscribe',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Choose your subscription plan',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: AppTheme.mediumGray,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startCheckout('monthly'),
                child: Text('Monthly - \$7'),
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startCheckout('annual'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warmBrown,
                ),
                child: Text('Annual - \$49 (Save \$35!)'),
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startCheckout('lifetime'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkerBrown,
                ),
                child: Text('Lifetime - \$99 (Never Pay Again!)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.warmBrown),
          ),
          SizedBox(height: 16),
          Text(
            'Validating license...',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              color: AppTheme.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _validateLicenseKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a license key'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
      return;
    }
    
    // Show progress message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔍 Validating license key...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
    
    final provider = Provider.of<LicenseProvider>(context, listen: false);
    bool success = false;
    String errorDetails = '';
    
    // Determine key type and validate accordingly
    if (key.startsWith('ij_life_')) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🌐 Connecting to backend server...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        success = await provider.validateLifetimeKey(key);
        if (!success) {
          errorDetails = 'Backend rejected the key';
        }
      } catch (e) {
        errorDetails = 'Connection failed: ${e.toString().substring(0, 100)}...';
      }
    } else if (key.startsWith('ij_sub_')) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🌐 Connecting to backend server...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        success = await provider.validateSubscriptionKey(key);
        if (!success) {
          errorDetails = 'Backend rejected the key';
        }
      } catch (e) {
        errorDetails = 'Connection failed: ${e.toString().substring(0, 100)}...';
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid license key format. Keys should start with ij_life_ or ij_sub_'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
      return;
    }
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ License validated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Validation failed: $errorDetails'),
          backgroundColor: AppTheme.warningRed,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
  
  Future<void> _startCheckout(String planType) async {
    // Use specific payment links for each plan type
    String paymentUrl;
    String planName;
    
    switch (planType) {
      case 'monthly':
        paymentUrl = 'https://pay.islajournal.app/b/dRmaEWct2cT03BN6JY73G01';
        planName = 'Monthly';
        break;
      case 'annual':
        paymentUrl = 'https://pay.islajournal.app/b/7sY28qakUg5cfkv2tI73G02';
        planName = 'Annual';
        break;
      case 'lifetime':
        paymentUrl = 'https://pay.islajournal.app/b/cNieVc50A7yGfkv4BQ73G00';
        planName = 'Lifetime';
        break;
      default:
        return;
    }
    
    // Open specific payment link in browser
    await BrowserService.openUrlWithConfirmation(
      context, 
      paymentUrl,
      title: 'Complete $planName Purchase',
    );
    
    // Show helpful message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$planName purchase page opened in browser! Complete your purchase and then enter your license key above.'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 10),
      ),
    );
  }
}
 