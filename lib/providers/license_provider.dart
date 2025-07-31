import 'package:flutter/material.dart';
import '../services/license_service.dart';

class LicenseProvider extends ChangeNotifier {
  LicenseStatus? _licenseStatus;
  bool _isInitialized = false;

  LicenseStatus? get licenseStatus => _licenseStatus;
  bool get isInitialized => _isInitialized;

  // Convenience getters
  bool get isValid => _licenseStatus?.isValid ?? false;
  bool get isLifetime => _licenseStatus?.isLifetime ?? false;
  bool get isSubscription => _licenseStatus?.isSubscription ?? false;
  bool get needsLicense => !isValid;

  Future<void> initialize() async {
    debugPrint('🚀 LicenseProvider initializing...');
    await checkLicense();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<void> checkLicense() async {
    try {
      _licenseStatus = await LicenseService().checkLicense();
      debugPrint(
          '✅ License Status: ${_licenseStatus?.type}, Valid: ${_licenseStatus?.isValid}');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('❌ License check error: $e');
      _licenseStatus = LicenseStatus(type: LicenseType.none, isValid: false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Validate lifetime license key manually
  Future<bool> validateLifetimeKey(String licenseKey) async {
    try {
      final result = await LicenseService().validateLifetimeKey(licenseKey);

      if (result.isValid) {
        _licenseStatus = result;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Lifetime key validation error: $e');
      return false;
    }
  }

  /// Validate subscription license key manually
  Future<bool> validateSubscriptionKey(String licenseKey) async {
    try {
      final result = await LicenseService().validateSubscriptionKey(licenseKey);

      if (result.isValid) {
        _licenseStatus = result;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Subscription key validation error: $e');
      return false;
    }
  }

  /// Create Stripe checkout session
  Future<String?> createCheckoutSession(String planType) async {
    try {
      final result = await LicenseService().createCheckoutSession(planType);
      return result['checkout_url'];
    } catch (e) {
      debugPrint('❌ Checkout session error: $e');
      return null;
    }
  }

  /// Get customer portal URL
  Future<String?> getCustomerPortalUrl() async {
    try {
      return await LicenseService().getCustomerPortalUrl();
    } catch (e) {
      debugPrint('❌ Customer portal error: $e');
      return null;
    }
  }

  /// Clear license data
  Future<void> clearLicenseData() async {
    debugPrint('🧹 LicenseProvider: Clearing license data...');

    // Clear all data from storage
    await LicenseService().clearLicenseData();

    // Set to invalid state immediately
    _licenseStatus = LicenseStatus(type: LicenseType.none, isValid: false);
    debugPrint('🔒 License set to invalid, notifying listeners...');

    // Notify UI immediately that license is now invalid
    notifyListeners();

    debugPrint('✅ License data cleared and UI notified');
  }
}
