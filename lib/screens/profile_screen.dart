import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'login_screen.dart';
import 'my_listings_screen.dart';
import 'host/host_bookings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _profileImage;
  File? _cnicFront;
  File? _cnicBack;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user != null) {
      _emailController.text = user.email;
      _cityController.text = user.location?.city ?? '';
      _areaController.text = user.location?.area ?? '';
      _phoneController.text = user.phoneNumber;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      if (type == 'profile') _profileImage = File(picked.path);
      if (type == 'cnic_front') _cnicFront = File(picked.path);
      if (type == 'cnic_back') _cnicBack = File(picked.path);
    });
  }

  Future<String?> _uploadToStorage(String uid, File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child('users/$uid/$path');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    if (_cityController.text.isEmpty || _areaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in City and Area')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{};

      if (_profileImage != null) {
        updates['profilePhoto'] =
            await _uploadToStorage(user.id, _profileImage!, 'profile.jpg');
      }

      if (_emailController.text.isNotEmpty) {
        updates['email'] = _emailController.text.trim();
      }
      if (_cityController.text.isNotEmpty) {
        updates['location.city'] = _cityController.text.trim();
      }
      if (_areaController.text.isNotEmpty) {
        updates['location.area'] = _areaController.text.trim();
      }
      if (_phoneController.text.isNotEmpty) {
        updates['phoneNumber'] = _phoneController.text.trim();
      }

      await authProvider.updateProfile(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF7C3AED),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, user),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReputationSection(user),
                  const SizedBox(height: 32),
                  _buildHostHub(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 16),
                  _buildInfoSection(user),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Identity Verification'),
                  const SizedBox(height: 16),
                  _buildVerificationSection(user),
                  const SizedBox(height: 40),
                  CustomButton(
                    text: 'Save Changes',
                    onPressed: _saveProfile,
                    isLoading: _isSaving,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 20),
                  _buildLogoutButton(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return SliverAppBar(
      expandedHeight: 280.0,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF7C3AED),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Pattern/Image
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                ),
              ),
            ),
            // Glassmorphism effect overlay
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (user.profilePhoto != null
                                ? NetworkImage(user.profilePhoto!)
                                : null) as ImageProvider?,
                        child: (_profileImage == null && user.profilePhoto == null)
                            ? const Icon(Icons.person, size: 50, color: Colors.grey)
                            : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.gallery, 'profile'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8)
                          ],
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 18, color: Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.email,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReputationSection(dynamic user) {
    return Row(
      children: [
        Expanded(
          child: _ReputationCard(
            label: 'Host Rating',
            rating: user.hostRating ?? 0.0,
            count: user.hostReviewCount ?? 0,
            color: const Color(0xFF7C3AED),
            icon: Icons.verified_user_outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ReputationCard(
            label: 'Renter Rating',
            rating: user.renterRating ?? 0.0,
            count: user.renterReviewCount ?? 0,
            color: const Color(0xFF0EA5E9),
            icon: Icons.stars_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildHostHub(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Host Hub'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _HubButton(
                icon: Icons.directions_car_filled_rounded,
                label: 'My Cars',
                color: const Color(0xFF7C3AED),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyListingsScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HubButton(
                icon: Icons.inbox_rounded,
                label: 'Requests',
                color: const Color(0xFF059669),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HostBookingsScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          CustomTextField(
            controller: _emailController,
            label: 'Email Address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _cityController,
                  label: 'City',
                  prefixIcon: Icons.location_city_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomTextField(
                  controller: _areaController,
                  label: 'Area',
                  prefixIcon: Icons.map_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection(dynamic user) {
    final status = user.cnic?.verificationStatus ?? 'not_submitted';
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CNIC Verification',
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${user.cnic?.number ?? "Number not provided"}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _VerificationImageCard(
                  label: 'Front Side',
                  url: user.cnic?.frontImage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VerificationImageCard(
                  label: 'Back Side',
                  url: user.cnic?.backImage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout_rounded, color: Colors.red),
        label: Text(
          'Log out of RozRides',
          style: GoogleFonts.outfit(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out from your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'verified':
      case 'approved': return const Color(0xFF10B981);
      case 'pending':  return const Color(0xFFF59E0B);
      case 'rejected': return const Color(0xFFEF4444);
      default:         return Colors.grey;
    }
  }
}

class _ReputationCard extends StatelessWidget {
  final String label;
  final double rating;
  final int count;
  final Color color;
  final IconData icon;

  const _ReputationCard({
    required this.label,
    required this.rating,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFACC15), size: 18),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1),
                  style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
          Text('$count reviews',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _HubButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HubButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.outfit(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _VerificationImageCard extends StatelessWidget {
  final String label;
  final String? url;

  const _VerificationImageCard({
    required this.label,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            image: url != null
                ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
                : null,
          ),
          child: url == null
              ? const Icon(Icons.image_not_supported_outlined, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 6),
        Center(
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11))),
      ],
    );
  }
}
