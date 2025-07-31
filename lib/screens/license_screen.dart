import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/license_provider.dart';
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
    try {
      const portalUrl = 'https://pay.islajournal.app/p/login/cNieVc50A7yGfkv4BQ73G00';
      
      // Open portal in inline webview dialog
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => CustomerPortalDialog(
          portalUrl: portalUrl,
        ),
      );
      
      if (result == true) {
        // User completed login and accessed their key, refresh license status
        final provider = Provider.of<LicenseProvider>(context, listen: false);
        await provider.checkLicense();
        if (provider.isValid) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Portal accessed! Copy your license key from the portal and enter it above.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening customer portal: $e'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
    }
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

class CustomerPortalDialog extends StatefulWidget {
  final String portalUrl;
  
  const CustomerPortalDialog({
    Key? key,
    required this.portalUrl,
  }) : super(key: key);
  
  @override
  State<CustomerPortalDialog> createState() => _CustomerPortalDialogState();
}

class _CustomerPortalDialogState extends State<CustomerPortalDialog> {
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
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Header with close button
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkerCream,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Customer Portal - Access Your License Key',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.close, color: AppTheme.darkText),
                  ),
                ],
              ),
            ),
            
            // Loading indicator
            if (_isLoading)
              Container(
                height: 4,
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.mediumGray,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
                ),
              ),
              
            // WebView
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: WebViewWidget(controller: controller),
              ),
            ),
            
            // Footer with instructions
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkerCream,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warmBrown, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Copy your license key from the portal, then close this dialog and paste it above',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12.0,
                        color: AppTheme.mediumGray,
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

 