// user_cubit.dart: Real Supabase auth state management.
// Part of LeoBook App — State Management (Cubit)
//
// Classes: UserCubit

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, AuthChangeEvent;
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/twilio_service.dart';

part 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  final AuthRepository _authRepo;
  StreamSubscription<AuthState>? _authSub;

  UserCubit(this._authRepo)
      : super(const UserInitial(user: UserModel(id: 'guest'))) {
    _listenToAuthChanges();
    _restoreSession();
  }

  // ─── Auth Listeners ──────────────────────────────────────────────

  void _listenToAuthChanges() {
    _authSub = _authRepo.authStateChanges.listen((authState) {
      final event = authState.event;
      if (event == AuthChangeEvent.signedIn) {
        final user = _authRepo.currentUser;
        if (user != null) {
          final model = UserModel.fromSupabaseUser(user);
          if (model.isProfileComplete) {
            emit(UserAuthenticated(user: model));
          } else {
            emit(UserProfileIncomplete(user: model));
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        emit(const UserInitial(user: UserModel(id: 'guest')));
      }
    });
  }

  /// Check if there's an existing session on cold start.
  void _restoreSession() {
    final user = _authRepo.currentUser;
    if (user != null) {
      final model = UserModel.fromSupabaseUser(user);
      if (model.isProfileComplete) {
        emit(UserAuthenticated(user: model));
      } else {
        emit(UserProfileIncomplete(user: model));
      }
    }
  }

  void _sendLoginNotification(String? phone) {
    if (phone != null && phone.isNotEmpty) {
      // In a background unawaited future
      TwilioService.sendDeviceLoginNotification(phone);
    }
  }

  // ─── Google Sign-In ──────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    emit(UserLoading(user: state.user));
    try {
      final response = await _authRepo.signInWithGoogle();
      if (response.user != null) {
        emit(UserAuthenticated(
          user: UserModel.fromSupabaseUser(response.user!),
        ));
      } else if (kIsWeb) {
        // On web, OAuth redirects the page — session arrives via authStateChanges.
        // Reset to initial so the UI isn't stuck on loading.
        emit(UserInitial(user: state.user));
      } else {
        emit(UserError(user: state.user, message: 'Google sign-in failed.'));
      }
    } catch (e) {
      emit(UserError(
        user: state.user,
        message: e.toString(),
      ));
    }
  }

  // ─── Phone OTP ───────────────────────────────────────────────────

  Future<void> sendPhoneOtp(String phone) async {
    emit(UserLoading(user: state.user));
    try {
      await _authRepo.sendPhoneOtp(phone);
      // Stay in loading — the UI will navigate to OTP screen
      emit(UserInitial(user: state.user));
    } catch (e) {
      emit(UserError(
        user: state.user,
        message: 'Failed to send OTP: ${e.toString()}',
      ));
    }
  }

  Future<void> verifyPhoneOtp(String phone, String token) async {
    emit(UserLoading(user: state.user));
    try {
      final response = await _authRepo.verifyPhoneOtp(phone, token);
      if (response.user != null) {
        emit(UserAuthenticated(
          user: UserModel.fromSupabaseUser(response.user!),
        ));
      } else {
        emit(UserError(user: state.user, message: 'OTP verification failed.'));
      }
    } catch (e) {
      emit(UserError(
        user: state.user,
        message: 'Invalid OTP: ${e.toString()}',
      ));
    }
  }

  // ─── Email Auth ──────────────────────────────────────────────────

  Future<void> signUpWithEmail(String email, String password) async {
    emit(UserLoading(user: state.user));
    try {
      final response = await _authRepo.signUpWithEmail(email, password);
      if (response.user != null) {
        emit(UserAuthenticated(
          user: UserModel.fromSupabaseUser(response.user!),
        ));
      } else {
        // Email confirmation required — user registered but not yet verified
        emit(UserInitial(user: state.user));
      }
    } catch (e) {
      emit(UserError(
        user: state.user,
        message: 'Sign-up failed: ${e.toString()}',
      ));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(UserLoading(user: state.user));
    try {
      final response = await _authRepo.signInWithEmail(email, password);
      if (response.user != null) {
        final model = UserModel.fromSupabaseUser(response.user!);
        if (model.isProfileComplete) {
          _sendLoginNotification(model.phone);
          emit(UserAuthenticated(user: model));
        } else {
          emit(UserProfileIncomplete(user: model));
        }
      } else {
        emit(UserError(user: state.user, message: 'Email sign-in failed.'));
      }
    } catch (e) {
      emit(UserError(
        user: state.user,
        message: e.toString(),
      ));
    }
  }

  // ─── Skip (Guest) ───────────────────────────────────────────────

  void skipAsGuest() {
    emit(const UserInitial(user: UserModel(id: 'guest')));
  }

  // ─── Super LeoBook (Subscription toggle with persistence) ───────

  void upgradeToSuperLeoBook() {
    final activatedAt = DateTime.now().toIso8601String();
    
    // Save to Supabase metadata in background so it persists across sessions
    _authRepo.updateUserMetadata({
      'super_leobook_activated_at': activatedAt,
    }).catchError((e) {
      debugPrint('[UserCubit] Failed to persist Super LeoBook activation: $e');
      throw e;
    });

    final upgraded = state.user.copyWith(
      isSuperLeoBook: true,
      tier: UserTier.pro,
    );
    emit(UserAuthenticated(user: upgraded));
  }

  void cancelSuperLeoBook() {
    // Clear from Supabase metadata
    _authRepo.updateUserMetadata({
      'super_leobook_activated_at': null,
    }).catchError((e) {
      debugPrint('[UserCubit] Failed to clear Super LeoBook activation: $e');
      throw e;
    });

    final downgraded = state.user.copyWith(
      isSuperLeoBook: false,
      tier: UserTier.lite,
    );
    emit(UserAuthenticated(user: downgraded));
  }

  // ─── Logout ──────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _authRepo.signOut();
    } catch (e) {
      debugPrint('[UserCubit] Sign out error: $e');
    }
    emit(const UserInitial(user: UserModel(id: 'guest')));
  }

  // ─── Legacy (test helpers) ───────────────────────────────────────

  void loginAsLite() {
    emit(UserAuthenticated(
      user: UserModel.lite(id: 'demo_lite', email: 'lite@leobook.com'),
    ));
  }

  void loginAsPro() {
    emit(UserAuthenticated(
      user: UserModel.pro(id: 'demo_pro', email: 'pro@leobook.com'),
    ));
  }

  void toggleTier(UserTier tier) {
    if (tier == UserTier.lite) {
      loginAsLite();
    } else if (tier == UserTier.pro) {
      loginAsPro();
    } else {
      logout();
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
