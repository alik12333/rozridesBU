import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'login_screen.dart';
import 'my_listings_screen.dart';
import 'host/incoming_requests_screen.dart';

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

      // Profile image
      if (_profileImage != null) {
        updates['profilePhoto'] =
        await _uploadToStorage(user.id, _profileImage!, 'profile.jpg');
      }

      // CNIC images
      if (_cnicFront != null || _cnicBack != null) {
        updates['cnic'] = {
          'frontImage': _cnicFront != null
              ? await _uploadToStorage(user.id, _cnicFront!, 'cnic/front.jpg')
              : user.cnic?.frontImage,
          'backImage': _cnicBack != null
              ? await _uploadToStorage(user.id, _cnicBack!, 'cnic/back.jpg')
              : user.cnic?.backImage,
          'verificationStatus': 'pending',
          'number': user.cnic?.number,
        };
      }

      // Text fields
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
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmed == true && mounted) {
                    await authProvider.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColorDark,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : (user.profilePhoto != null
                                      ? NetworkImage(user.profilePhoto!) as ImageProvider
                                      : null),
                              child: (_profileImage == null && user.profilePhoto == null)
                                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _pickImage(ImageSource.gallery, 'profile'),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Host Shortcuts (Temporarily ignoring isOwner check for testing)
                  Text(
                    'Host Shortcuts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildMenuTile(
                    context: context,
                    icon: Icons.directions_car_rounded,
                    label: 'My Listed Cars',
                    subtitle: 'View, edit or remove your car listings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyListingsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuTile(
                    context: context,
                    icon: Icons.inbox_rounded,
                    label: 'Incoming Requests',
                    subtitle: 'View and manage booking requests',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IncomingRequestsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Ratings section
                  if ((user.hostRating ?? 0) > 0 || (user.renterRating ?? 0) > 0) ...[
                    Text('Reputation', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(children: [
                      if ((user.hostRating ?? 0) > 0)
                        Expanded(child: _RatingBadge(
                          label: 'As Host',
                          rating: user.hostRating!,
                          count: user.hostReviewCount ?? 0,
                          color: const Color(0xFF7C3AED),
                        )),
                      if ((user.hostRating ?? 0) > 0 && (user.renterRating ?? 0) > 0)
                        const SizedBox(width: 12),
                      if ((user.renterRating ?? 0) > 0)
                        Expanded(child: _RatingBadge(
                          label: 'As Renter',
                          rating: user.renterRating!,
                          count: user.renterReviewCount ?? 0,
                          color: const Color(0xFF0EA5E9),
                        )),
                    ]),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),
                  ],

                  // Contact Information

                  Text(
                    'Contact Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  CustomTextField(
                    controller: TextEditingController(text: user.fullName),
                    label: 'Full Name',
                    enabled: false,
                    prefixIcon: Icons.person,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    prefixIcon: Icons.email,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    prefixIcon: Icons.phone,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _cityController,
                          label: 'City',
                          prefixIcon: Icons.location_city,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          controller: _areaController,
                          label: 'Area',
                          prefixIcon: Icons.map,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),



                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  // CNIC Verification
                  Text(
                    'Identity Verification',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Required for listing cars and renting',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  CustomTextField(
                    controller:
                        TextEditingController(text: user.cnic?.number ?? ''),
                    label: 'CNIC Number',
                    enabled: false,
                    prefixIcon: Icons.badge,
                    hint: 'e.g., 42201-1234567-1',
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _buildImageUploadCard(
                          'Front Side',
                          'cnic_front',
                          _cnicFront,
                          user.cnic?.frontImage,
                          false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildImageUploadCard(
                          'Back Side',
                          'cnic_back',
                          _cnicBack,
                          user.cnic?.backImage,
                          false,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(user.cnic?.verificationStatus).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(user.cnic?.verificationStatus).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(user.cnic?.verificationStatus),
                          size: 20,
                          color: _getStatusColor(user.cnic?.verificationStatus),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Status: ${user.cnic != null ? user.cnic!.verificationStatus.toUpperCase() : 'NOT SUBMITTED'}',
                          style: TextStyle(
                            color: _getStatusColor(user.cnic?.verificationStatus),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  CustomButton(
                    text: 'Save Changes',
                    onPressed: _saveProfile,
                    isLoading: _isSaving,
                    icon: Icons.save_rounded,
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'verified':
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'verified':
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'rejected':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Widget _buildImageUploadCard(String label, String type, File? file, String? existingUrl, [bool isEditable = true]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isEditable ? () => _showImagePickerOptions(type) : null,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              image: file != null
                  ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                  : (existingUrl != null
                      ? DecorationImage(
                          image: NetworkImage(existingUrl),
                          fit: BoxFit.cover,
                        )
                      : null),
            ),
            child: file == null && existingUrl == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: Colors.grey.shade400),
                      const SizedBox(height: 4),
                      Text(
                        'Upload',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  )
                : (isEditable ? Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.edit, color: Colors.white),
                    ),
                  ) : null), // No edit icon if not editable
          ),
        ),
      ],
    );
  }

  void _showImagePickerOptions(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera, type);
                  },
                ),
                _buildOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery, type);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 22, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 15, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─── Rating Badge Widget ──────────────────────────────────────────────────────

class _RatingBadge extends StatelessWidget {
  final String label;
  final double rating;
  final int count;
  final Color color;

  const _RatingBadge({
    required this.label,
    required this.rating,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFACC15), size: 20),
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        Text('$count ${count == 1 ? "review" : "reviews"}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    );
  }
}
