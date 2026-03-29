// profile_setup_screen.dart: Post-Auth complete profile setup.
// Part of LeoBook App — Screens

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:leobookapp/core/constants/app_colors.dart';
import 'package:leobookapp/logic/cubit/user_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:leobookapp/presentation/screens/main_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _phoneNeedsVerification = false;
  bool _phoneOtpSent = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserCubit>().state.user;
    
    // Auto-fill from whatever data they signed in with
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone == null ? '' : '+${user.phone!.replaceAll('+', '')}';
    
    // Default username to phone if available
    _usernameController.text = _phoneController.text.isNotEmpty ? _phoneController.text : '';
    
    // If they already have a phone from auth, skip verification
    _phoneNeedsVerification = user.phone == null || user.phone!.isEmpty;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Regex string validators
  bool _isValidPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#\$&*~]'))) return false;
    return true;
  }

  Future<void> _sendPhoneOtp() async {
    if (_phoneController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.updateUser(
        UserAttributes(phone: _phoneController.text.trim()),
      );
      if (!mounted) return;
      
      setState(() => _phoneOtpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to your phone')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending OTP: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtpAndComplete() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_phoneNeedsVerification && !_phoneOtpSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your phone number first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // 1. Verify OTP if needed
      if (_phoneNeedsVerification && _phoneOtpSent) {
        await supabase.auth.verifyOTP(
          type: OtpType.phoneChange,
          phone: _phoneController.text.trim(),
          token: _otpController.text.trim(),
        );
      }

      // 2. Update all other attributes (Email, Password, Username, Completion flag)
      final updateData = {
        'username': _usernameController.text.trim(),
        'profile_completed': true,
      };

      await supabase.auth.updateUser(
        UserAttributes(
          email: _emailController.text.isEmpty ? null : _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: updateData,
        ),
      );

      // Force session refresh for Cubit to pick it up
      await supabase.auth.refreshSession();
      
      if (!mounted) return;
      
      // Navigate to Main Screen directly handling transition
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
                Text(
                  'Just one last step!',
                  style: GoogleFonts.lexend(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'To secure your LeoBook account, please complete your profile details.',
                  style: GoogleFonts.lexend(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                
                // Username
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Username'),
                  validator: (v) => v!.isEmpty ? 'Username required' : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v!.isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Set a Secure Password'),
                  obscureText: true,
                  validator: (v) {
                    if (v!.isEmpty) return 'Password required';
                    if (!_isValidPassword(v)) {
                      return '8+ chars, 1 uppercase, 1 lower, 1 digit, 1 special';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Phone Number (+234...)'),
                  keyboardType: TextInputType.phone,
                  enabled: _phoneNeedsVerification && !_phoneOtpSent,
                  validator: (v) => v!.isEmpty ? 'Phone required' : null,
                ),
                const SizedBox(height: 16),

                // Phone Verification (Only if needed)
                if (_phoneNeedsVerification) ...[
                  if (!_phoneOtpSent)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neutral700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isLoading ? null : _sendPhoneOtp,
                      child: Text(
                        'Send Verification OTP',
                        style: GoogleFonts.lexend(color: Colors.white),
                      ),
                    )
                  else ...[
                    TextFormField(
                      controller: _otpController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Enter 6-digit OTP code'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'OTP required' : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'OTP sent via SMS. Enter it above to verify.',
                      style: GoogleFonts.lexend(fontSize: 12, color: AppColors.primary),
                    )
                  ],
                  const SizedBox(height: 32),
                ],

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _verifyOtpAndComplete,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.black),
                        )
                      : Text(
                          'Save & Finish',
                          style: GoogleFonts.lexend(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.neutral900,
      appBar: AppBar(
        title: Text(
          'Complete Profile',
          style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 1024;
            
            if (isDesktop) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Container(
                    width: 420,
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 32),
                    decoration: BoxDecoration(
                      color: AppColors.neutral800,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: formContent,
                  ),
                ),
              );
            }
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: formContent,
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textDisabled),
      filled: true,
      fillColor: AppColors.neutral800,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
