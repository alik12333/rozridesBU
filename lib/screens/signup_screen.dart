import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'main_navigation.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // User info
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // CNIC
  final TextEditingController _cnicNumberController = TextEditingController();
  File? _cnicFront;
  File? _cnicBack;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSigningUp = false;
  bool? _hasDrivingLicense;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cnicNumberController.dispose();
    super.dispose();
  }

  String _getFullPhoneNumber() {
    String phone = _phoneController.text.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    return '+92$phone';
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      if (type == 'cnic_front') _cnicFront = File(picked.path);
      if (type == 'cnic_back') _cnicBack = File(picked.path);
    });
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_cnicNumberController.text.isEmpty || _cnicFront == null || _cnicBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide CNIC number, front and back images')),
      );
      return;
    }

    setState(() => _isSigningUp = true);

    final authProvider = context.read<AuthProvider>();

    try {
      bool success = await authProvider.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phoneNumber: _getFullPhoneNumber(),
        city: _cityController.text.trim(),
        area: _areaController.text.trim(),
        cnicNumber: _cnicNumberController.text.trim(),
        cnicFront: _cnicFront,
        cnicBack: _cnicBack,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Signup failed'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSigningUp = false);
    }
  }

  Widget _cnicUploadField(String label, String type, File? file) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                  image: file != null ? DecorationImage(image: FileImage(file), fit: BoxFit.cover) : null,
                ),
                child: file == null ? const Center(child: Text('No image selected')) : null,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library),
                  onPressed: () => _pickImage(ImageSource.gallery, type),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () => _pickImage(ImageSource.camera, type),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColorDark,
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColorLight,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_add,
                                  size: 40,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Create Account',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign up to get started with RozRides',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        CustomTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'e.g. John Doe',
                          prefixIcon: Icons.person_outline,
                          maxLength: 50,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter your name';
                            if (v.length < 2) return 'Name is too short';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'example@mail.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          maxLength: 254,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter your email';
                            if (v.length < 5) return 'Email is too short';
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(v)) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hint: '300 1234567',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          maxLength: 20,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter your phone number';
                            if (v.length != 10) return 'Enter exactly 10 digits';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _cityController,
                                label: 'City',
                                hint: 'e.g. Lahore',
                                prefixIcon: Icons.location_city,
                                maxLength: 30,
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _areaController,
                                label: 'Area',
                                hint: 'e.g. Gulberg',
                                prefixIcon: Icons.map,
                                maxLength: 30,
                                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Create password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          maxLength: 64,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter a password';
                            if (v.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hint: 'Repeat password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscureConfirmPassword,
                          maxLength: 64,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                        ),
                        const SizedBox(height: 24),

                        // CNIC Section
                        Text(
                          'Identity Verification',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _cnicNumberController,
                          label: 'CNIC Number',
                          hint: '42201-1234567-1',
                          keyboardType: TextInputType.number,
                          maxLength: 13,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
                          validator: (v) => (v == null || v.length != 13) ? 'Enter 13 digits' : null,
                        ),
                        const SizedBox(height: 16),
                        _cnicUploadField('CNIC Front', 'cnic_front', _cnicFront),
                        const SizedBox(height: 16),
                        _cnicUploadField('CNIC Back', 'cnic_back', _cnicBack),
                        const SizedBox(height: 32),

                        // Driving License Toggle
                        Text(
                          'Do you have a valid driving licence?',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _hasDrivingLicense = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _hasDrivingLicense == true ? Colors.green : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _hasDrivingLicense == true ? Colors.green : Colors.grey.shade400,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Yes',
                                    style: TextStyle(
                                      color: _hasDrivingLicense == true ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _hasDrivingLicense = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _hasDrivingLicense == false ? Colors.red : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _hasDrivingLicense == false ? Colors.red : Colors.grey.shade400,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'No',
                                    style: TextStyle(
                                      color: _hasDrivingLicense == false ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_hasDrivingLicense == false)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'A driving licence is important to make a account',
                              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(height: 32),

                        // Error message
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) {
                            if (auth.status == AuthStatus.error && auth.errorMessage != null) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          auth.errorMessage!,
                                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        CustomButton(
                          text: 'Sign Up',
                          onPressed: _hasDrivingLicense == true ? () => _signUp() : () {},
                          isDisabled: _hasDrivingLicense != true,
                          isLoading: _isSigningUp,
                          icon: Icons.person_add,
                        ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Already have an account? ", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                              },
                              child: const Text('Login', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
