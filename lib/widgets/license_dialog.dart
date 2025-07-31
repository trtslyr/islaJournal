import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/license_provider.dart';

import '../core/theme/app_theme.dart';

class LicenseDialog extends StatefulWidget {
  final bool canDismiss;
  
  const LicenseDialog({
    Key? key,
    this.canDismiss = true,
  }) : super(key: key);
  
  @override
  State<LicenseDialog> createState() => _LicenseDialogState();
}

class _LicenseDialogState extends State<LicenseDialog> {
  final TextEditingController _keyController = TextEditingController();
  
  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.creamBeige,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: EdgeInsets.all(24),
        child: Consumer<LicenseProvider>(
          builder: (context, license, child) {
            if (false) { // Loading state removed
              return _buildLoadingView();
            }
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'isla journal',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    if (widget.canDismiss)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: AppTheme.mediumGray),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'activate your license',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                    color: AppTheme.mediumGray,
                  ),
                ),
                SizedBox(height: 24),
                
                // Trial status if active
                _buildTrialStatus(license),
                if (license.isTrial) SizedBox(height: 24),
                
                // License options
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildLifetimeSection(),
                        SizedBox(height: 16),
                        _buildOrDivider(),
                        SizedBox(height: 16),
                        _buildSubscriptionSection(),
                        // Error handling simplified in new system
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildTrialStatus(LicenseProvider license) {
    if (license.licenseStatus?.isTrial == true) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warmBrown.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.timer, color: AppTheme.warmBrown, size: 20),
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
                      fontSize: 12,
                      color: AppTheme.darkText,
                    ),
                  ),
                  Text(
                    '${license.licenseStatus!.trialHoursRemaining} hours remaining',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return SizedBox.shrink();
  }
  
  Widget _buildLifetimeSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars, color: AppTheme.warmBrown, size: 16),
              SizedBox(width: 8),
              Text(
                'Lifetime License',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Enter your lifetime license key',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              color: AppTheme.mediumGray,
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              hintText: 'ij_life_abc123...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(8),
              isDense: true,
            ),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                                    onPressed: _validateLicenseKey,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                'Activate Lifetime License',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
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
              fontSize: 12,
              color: AppTheme.mediumGray,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
  
  Widget _buildSubscriptionSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.subscriptions, color: AppTheme.warmBrown, size: 16),
              SizedBox(width: 8),
              Text(
                'Subscribe',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
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
              fontSize: 10,
              color: AppTheme.mediumGray,
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startCheckout('monthly'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text('Monthly - \$7', style: TextStyle(fontSize: 12)),
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startCheckout('annual'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warmBrown,
                padding: EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text('Annual - \$49 (Save \$35!)', style: TextStyle(fontSize: 12)),
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startCheckout('lifetime'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkerBrown,
                padding: EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text('Lifetime - \$99 (Never Pay Again!)', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return Container(
      height: 200,
      child: Center(
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
                fontSize: 12,
              ),
            ),
          ],
        ),
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
      Navigator.of(context).pop(); // Close dialog
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
        // Payment successful, refresh license status and close dialog
        await provider.checkLicense();
        if (mounted) {
          // Show success message with portal instructions
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎉 Payment successful!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '📧 Check your email for receipt details',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '🔑 Access your license key at: Settings → Account → Login to User Portal',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 8),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
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

class StripeCheckoutDialog extends StatefulWidget {
  final String checkoutUrl;
  
  const StripeCheckoutDialog({
    Key? key,
    required this.checkoutUrl,
  }) : super(key: key);
  
  @override
  State<StripeCheckoutDialog> createState() => _StripeCheckoutDialogState();
}

class _StripeCheckoutDialogState extends State<StripeCheckoutDialog> {
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
            
            // Check for success/cancel URLs
            if (url.contains('/success') || url.contains('checkout/session')) {
              // Payment successful
              Navigator.of(context).pop(true);
            } else if (url.contains('/cancel')) {
              // Payment cancelled
              Navigator.of(context).pop(false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.creamBeige,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: AppTheme.creamBeige,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: AppTheme.warmBrown.withOpacity(0.2))),
              ),
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Complete Purchase',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
            ),
            // WebView content
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                child: Stack(
                  children: [
                    WebViewWidget(controller: controller),
                    if (_isLoading)
                      Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppTheme.warmBrown),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 