import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class User {
  final String userId;
  final String email;
  final String fullName;

  User({
    required this.userId,
    required this.email,
    required this.fullName,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'fullName': fullName,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
    );
  }
}

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _currentUser;
  final _prefsKey = 'current_user';

  // Get current user
  User? get currentUser => _currentUser;

  // Initialize - load user from shared preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_prefsKey);
    if (userJson != null) {
      try {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromMap(userMap);
      } catch (e) {
        // Invalid user data, clear it
        await prefs.remove(_prefsKey);
      }
    }
  }

  // Get current user ID
  String? get userId => _currentUser?.userId;

  // Auth state changes stream
  // Note: This is a simple stream that returns current user
  // For real-time updates, you would need to implement a StreamController
  Stream<User?> get authStateChanges async* {
    yield _currentUser;
    // Stream completes after first value
    // Parent widget will check currentUser directly
  }

  // Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generate user ID from email
  String _generateUserId(String email) {
    final bytes = utf8.encode(email.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 28); // Use first 28 chars as userId
  }

  // Sign up with email and password
  Future<User> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final emailLower = email.toLowerCase().trim();
      final userId = _generateUserId(emailLower);
      
      // Check if user already exists
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        throw Exception('An account already exists for that email.');
      }

      // Hash password
      final hashedPassword = _hashPassword(password);

      // Create user document in Firestore
      await _db.collection('users').doc(userId).set({
        'userId': userId,
        'email': emailLower,
        'fullName': fullName.trim(),
        'passwordHash': hashedPassword,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create default user settings
      await _db
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('default')
          .set({
        'goalHours': 8.0,
        'bedtimeReminderEnabled': false,
        'bedtime': {'h': 23, 'm': 30},
        'wakeTime': {'h': 7, 'm': 0},
      });

      // Create user object (but don't sign in automatically)
      final user = User(
        userId: userId,
        email: emailLower,
        fullName: fullName.trim(),
      );

      // Don't save user to local storage or set currentUser
      // User needs to sign in manually after signup

      return user;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Sign in with email and password
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final emailLower = email.toLowerCase().trim();
      final userId = _generateUserId(emailLower);
      
      // Get user document from Firestore
      final userDoc = await _db.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        throw Exception('No user found for that email.');
      }

      final userData = userDoc.data()!;
      
      // Verify password
      final hashedPassword = _hashPassword(password);
      final storedPasswordHash = userData['passwordHash'] as String?;
      
      if (storedPasswordHash == null || storedPasswordHash != hashedPassword) {
        throw Exception('Wrong password provided.');
      }

      // Create user object and save to local storage
      final user = User(
        userId: userId,
        email: userData['email'] as String,
        fullName: userData['fullName'] as String,
      );

      await _saveUser(user);
      _currentUser = user;

      return user;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Sign out
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _currentUser = null;
  }

  // Reset password (update password in Firestore)
  Future<void> resetPassword(String email, String newPassword) async {
    try {
      final emailLower = email.toLowerCase().trim();
      final userId = _generateUserId(emailLower);
      
      // Get user document
      final userDoc = await _db.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        throw Exception('No user found for that email.');
      }

      // Hash new password
      final hashedPassword = _hashPassword(newPassword);

      // Update password
      await _db.collection('users').doc(userId).update({
        'passwordHash': hashedPassword,
      });
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Save user to local storage
  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = jsonEncode(user.toMap());
    await prefs.setString(_prefsKey, userJson);
  }
}
