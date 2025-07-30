import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/license_provider.dart';
import '../services/license_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/license_dialog.dart';

class LicenseScreen extends StatefulWidget {
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
      body: Center(
        child: Container(
          padding: EdgeInsets.all(32),
          constraints: BoxConstraints(maxWidth: 500),
          child: Consumer<LicenseProvider>(
            builder: (context, license, child) {
              if (false) { // Loading state removed
                return _buildLoadingView();
              }
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  SizedBox(height: 32),
                  _buildTrialStatus(license),
                  SizedBox(height: 32),
                  _buildLifetimeSection(),
                  SizedBox(height: 24),
                  _buildOrDivider(),
                  SizedBox(height: 24),
                  _buildSubscriptionSection(),
                  // Error handling simplified in new system
                ],
              );
            },
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
  
  Widget _buildTrialStatus(LicenseProvider license) {
    if (license.licenseStatus?.isTrial == true) {
      return Card(
        color: AppTheme.warmBrown.withOpacity(0.1),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.timer, color: AppTheme.warmBrown),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Trial Active',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    Text(
                      '${license.licenseStatus!.trialHoursRemaining} hours remaining',
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
      );
    }
    
    return SizedBox.shrink();
  }
  
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
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              color: AppTheme.mediumGray,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
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
  
  Widget _buildErrorMessage(String error) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningRed.withOpacity(0.1),
        border: Border.all(color: AppTheme.warningRed.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.warningRed, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: AppTheme.warningRed,
              ),
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
    
    final provider = Provider.of<LicenseProvider>(context, listen: false);
    bool success = false;
    
    // Determine key type and validate accordingly
    if (key.startsWith('ij_life_')) {
      success = await provider.validateLifetimeKey(key);
    } else if (key.startsWith('ij_sub_')) {
      success = await provider.validateSubscriptionKey(key);
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
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid license key. Please check and try again.'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
    }
  }
  
  Future<void> _startCheckout(String planType) async {
    final provider = Provider.of<LicenseProvider>(context, listen: false);
    final checkoutUrl = await provider.createCheckoutSession(planType);
    
    if (checkoutUrl != null) {
      // Open Stripe checkout in partial-screen dialog
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StripeCheckoutDialog(
          checkoutUrl: checkoutUrl,
        ),
      );
      
      if (result == true) {
        // Payment successful, refresh license status
        await provider.checkLicense();
        if (provider.isValid) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start checkout. Please try again.'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
    }
  }
}

 