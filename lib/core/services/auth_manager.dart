import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  bool _isGuest = false;
  bool _isAuthenticated = true; // TEMPORARY: Default to true
  String? _currentRole = 'client'; // TEMPORARY: Default to client
  String? _userId = 'mock-id';

  // Getters
  bool get isGuest => _isGuest;
  bool get isAuthenticated => _isAuthenticated;
  String? get currentRole => _currentRole;
  String? get userId => _userId;

  // Set guest mode
  void setGuestMode(bool isGuest) {
    _isGuest = isGuest;
    _isAuthenticated = !isGuest;
  }

  // Check if action requires authentication
  bool requiresAuthentication(String action) {
    if (_isGuest) {
      switch (action) {
        case 'book':
        case 'chat':
        case 'kazilive':
        case 'accept_booking':
          return true;
        default:
          return false;
      }
    }
    return false;
  }

  // Show authentication prompt
  void showAuthPrompt(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text(
          'Usajili Unahitajika',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          _getAuthMessage(action),
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Rudi',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAuth(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'Sajili',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getAuthMessage(String action) {
    switch (action) {
      case 'book':
        return 'Ili kuweka miadi, unahitaji kusajili kama mteja.';
      case 'chat':
        return 'Ili kuwasiliana na wataalamu, unahitaji kusajili.';
      case 'kazilive':
        return 'Ili kutumia Kazilive, unahitaji kusajili.';
      case 'accept_booking':
        return 'Ili kukubali miadi, unahitaji kusajili kama mtaalamu.';
      default:
        return 'Tafadhali sajili kuendelea.';
    }
  }

  void _navigateToAuth(BuildContext context) {
    context.push('/role_selection');
  }

  // Switch role
  void switchRole(String newRole) {
    _currentRole = newRole;
  }

  // Login user
  void login(String userId, String role) {
    _userId = userId;
    _currentRole = role;
    _isAuthenticated = true;
    _isGuest = false;
  }

  // Logout user
  void logout() {
    _userId = null;
    _currentRole = null;
    _isAuthenticated = false;
    _isGuest = false;
  }

  // Check if user can perform action
  bool canPerformAction(String action) {
    if (_isGuest) {
      return !requiresAuthentication(action);
    }
    
    if (!_isAuthenticated) {
      return false;
    }

    // Role-based permissions
    switch (action) {
      case 'accept_booking':
      case 'start_kazilive':
        return _currentRole == 'pro';
      case 'book':
      case 'chat':
        return _currentRole == 'client';
      default:
        return true;
    }
  }

  // Get user display name
  String getDisplayName() {
    if (_isGuest) return 'Mgeni';
    if (_currentRole == 'client') return 'Mteja';
    if (_currentRole == 'pro') return 'Mtaalamu';
    return 'Mtumiaji';
  }
}
