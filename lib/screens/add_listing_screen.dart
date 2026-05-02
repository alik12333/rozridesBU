import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/listing_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'listing_success_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'host/location_picker_screen.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _carNameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _engineSizeController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _carNumberController = TextEditingController();

  // State
  String _fuelType = 'Petrol';
  String _transmission = 'Manual';
  bool _withDriver = true;
  bool _hasInsurance = false;
  List<File> _images = [];
  bool _isSubmitting = false;
  LocationPickerResult? _locationResult;

  final List<String> _fuelTypes = ['Petrol', 'Diesel', 'Hybrid', 'Electric', 'CNG'];
  final List<String> _transmissions = ['Manual', 'Automatic'];

  @override
  void dispose() {
    _carNameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _priceController.dispose();
    _engineSizeController.dispose();
    _mileageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    if (pickedFiles.isNotEmpty) {
      setState(() {
        // Add new images to existing list (max 10 total)
        for (var file in pickedFiles) {
          if (_images.length < 10) {
            _images.add(File(file.path));
          }
        }
      });

      if (pickedFiles.length + _images.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 10 images allowed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_images.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 3 images for better visibility'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Insurance validation
    if (!_hasInsurance && !_withDriver) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If no insurance, car must be with driver'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_locationResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the car location on the map'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final listingProvider = context.read<ListingProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isSubmitting = true);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading images and creating listing...'),
                  SizedBox(height: 8),
                  Text(
                    'Please wait, this may take a moment',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      print('🚀 Starting listing creation...');
      print('📸 Images to upload: ${_images.length}');

      bool success = await listingProvider.createListing(
        ownerId: user.id,
        ownerName: user.fullName,
        ownerPhone: user.phoneNumber,
        carName: _carNameController.text.trim(),
        carNumber: _carNumberController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text),
        pricePerDay: double.parse(_priceController.text),
        engineSize: _engineSizeController.text.trim(),
        mileage: int.parse(_mileageController.text),
        fuelType: _fuelType,
        transmission: _transmission,
        description: _descriptionController.text.trim(),
        withDriver: _withDriver,
        hasInsurance: _hasInsurance,
        images: _images,
        city: _locationResult!.city ?? user.location?.city,
        area: _locationResult!.area ?? user.location?.area,
        location: GeoPoint(_locationResult!.latLng.latitude, _locationResult!.latLng.longitude),
        geohash: null, // Computed by ListingService from the GeoPoint
        locationLabel: _locationResult!.locationLabel,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        if (success) {
          print('✅ Listing created successfully!');

          // Navigate to success screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ListingSuccessScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(listingProvider.errorMessage ?? 'Failed to create listing'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error in _submitListing: $e');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // Check verification status
    if (user?.cnic?.verificationStatus != 'approved') {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title: Text('Add New Car', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gpp_bad_outlined, size: 80, color: Colors.orange.shade300),
                const SizedBox(height: 24),
                const Text(
                  'Verification Required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You must have a verified CNIC to list your car for rent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please perform identity verification in the Profile tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('Add New Car', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16).copyWith(bottom: Platform.isIOS ? 32 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: CustomButton(
          text: 'Add Car',
          onPressed: _isSubmitting ? () {} : _submitListing,
          isLoading: _isSubmitting,
          icon: Icons.check_circle_rounded,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Images Section
            _buildSection(
              title: 'Car Images',
              subtitle: 'Add 3-10 clear images of your car',
              children: [

              if (_images.isEmpty)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                          ),
                          child: const Icon(Icons.add_photo_alternate_rounded, size: 32, color: Color(0xFF7C3AED)),
                        ),
                        const SizedBox(height: 12),
                        Text('Tap to select images', style: GoogleFonts.outfit(color: const Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length + 1, // +1 for add button
                        itemBuilder: (context, index) {
                          if (index == _images.length) {
                            // Add more button
                            if (_images.length < 10) {
                              return GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey.shade100,
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add, color: Colors.grey),
                                      SizedBox(height: 4),
                                      Text('Add More', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }

                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _images[index],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                // Image number badge
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_images.length}/10 images added',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),

              ],
            ),
            
            // Basic Information
            _buildSection(
              title: 'Basic Information',
              icon: Icons.info_outline_rounded,
              iconColor: Colors.blue,
              children: [
                CustomTextField(
                  controller: _carNameController,
                  label: 'Car Title',
                  hint: 'e.g., Toyota Corolla GLi 2020',
                  prefixIcon: Icons.title_rounded,
                  validator: (value) => value == null || value.isEmpty ? 'Please enter car title' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _carNumberController,
                  label: 'Car Number (Private)',
                  hint: 'e.g., LEC-1234',
                  prefixIcon: Icons.numbers_rounded,
                  validator: (value) => value == null || value.isEmpty ? 'Car number is required for admin' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _brandController,
                        label: 'Brand',
                        hint: 'e.g., Toyota',
                        prefixIcon: Icons.branding_watermark_rounded,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: _modelController,
                        label: 'Model',
                        hint: 'e.g., Corolla',
                        prefixIcon: Icons.style_rounded,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _yearController,
                        label: 'Year',
                        hint: 'e.g., 2020',
                        prefixIcon: Icons.calendar_today_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          int? year = int.tryParse(value);
                          if (year == null || year < 1990 || year > DateTime.now().year + 1) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: _mileageController,
                        label: 'Mileage (KM)',
                        hint: 'e.g., 45000',
                        prefixIcon: Icons.speed_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Specifications
            _buildSection(
              title: 'Specifications',
              icon: Icons.settings_outlined,
              iconColor: Colors.orange,
              children: [
                CustomTextField(
                  controller: _engineSizeController,
                  label: 'Engine Size (CC)',
                  hint: 'e.g., 660, 1000, 1800',
                  prefixIcon: Icons.settings_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  validator: (value) => value == null || value.isEmpty ? 'Please enter engine size' : null,
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fuel Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _fuelType,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.local_gas_station_rounded, color: Color(0xFF7C3AED)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      ),
                      items: _fuelTypes.map((fuel) => DropdownMenuItem(value: fuel, child: Text(fuel))).toList(),
                      onChanged: (value) => setState(() => _fuelType = value!),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Transmission', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _transmission,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.settings_input_component_rounded, color: Color(0xFF7C3AED)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      ),
                      items: _transmissions.map((trans) => DropdownMenuItem(value: trans, child: Text(trans))).toList(),
                      onChanged: (value) => setState(() => _transmission = value!),
                    ),
                  ],
                ),

              ],
            ),

            // Pricing & Services
            _buildSection(
              title: 'Pricing & Services',
              icon: Icons.payments_outlined,
              iconColor: Colors.green,
              children: [

              // Price per Day
              CustomTextField(
                controller: _priceController,
                label: 'Price per Day (PKR)',
                hint: 'e.g., 5000',
                prefixText: 'PKR ',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter valid price';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // With Driver Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'With Driver',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Include driver service',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _withDriver,
                      activeColor: const Color(0xFF7C3AED),
                      onChanged: _hasInsurance
                          ? (value) {
                        setState(() {
                          _withDriver = value;
                        });
                      }
                          : null, // Disabled if no insurance
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Insurance Option Cards (Phase 2 requirement)
              const Text(
                'Does your car have valid insurance?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _hasInsurance = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasInsurance ? const Color(0xFF7C3AED) : Colors.grey.shade200,
                            width: _hasInsurance ? 2 : 1,
                          ),
                          color: _hasInsurance ? const Color(0xFF7C3AED).withValues(alpha: 0.05) : Colors.white,
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.verified_user_rounded,
                                color: _hasInsurance ? const Color(0xFF7C3AED) : Colors.grey.shade400,
                                size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Yes — Car is insured',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _hasInsurance ? const Color(0xFF7C3AED) : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _hasInsurance = false;
                        _withDriver = true; // Force driver if no insurance
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_hasInsurance ? Colors.orange : Colors.grey.shade200,
                            width: !_hasInsurance ? 2 : 1,
                          ),
                          color: !_hasInsurance ? Colors.orange.shade50 : Colors.white,
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.gpp_maybe_rounded,
                                color: !_hasInsurance ? Colors.orange : Colors.grey.shade400,
                                size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'No — Uninsured',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !_hasInsurance ? Colors.orange.shade800 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (!_hasInsurance)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Without insurance, driver must be included',
                            style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              ],
            ),

            // Description
            _buildSection(
              title: 'Description',
              icon: Icons.description_outlined,
              iconColor: Colors.deepPurple,
              children: [

              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Describe your car in detail (condition, features, special notes, etc.)',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.length < 20) {
                    return 'Description should be at least 20 characters';
                  }
                  return null;
                },
              ),

              ],
            ),

            // Location Picker
            _buildSection(
              title: 'Location',
              icon: Icons.location_on_outlined,
              iconColor: Colors.red,
              subtitle: 'Pin exactly where this car is available for pickup',
              children: [
                InkWell(
                  onTap: () async {
                    final LocationPickerResult? result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LocationPickerScreen(),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _locationResult = result;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: _locationResult == null ? Colors.red.shade300 : const Color(0xFF16A34A)),
                      borderRadius: BorderRadius.circular(12),
                      color: _locationResult == null ? Colors.red.shade50 : const Color(0xFF16A34A).withValues(alpha: 0.05),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _locationResult == null ? Icons.location_off_rounded : Icons.location_on_rounded,
                          color: _locationResult == null ? Colors.red : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _locationResult == null
                              ? 'Tap to pick car location (Required)'
                              : _locationResult!.locationLabel,
                            style: GoogleFonts.outfit(
                              color: _locationResult == null ? Colors.red.shade700 : const Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: _locationResult == null ? Colors.red : const Color(0xFF16A34A)),
                      ],
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

  Widget _buildSection({
    required String title,
    String? subtitle,
    required List<Widget> children,
    IconData? icon,
    Color? iconColor,
  }) {
    final Color sectionColor = iconColor ?? const Color(0xFF7C3AED);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: sectionColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: sectionColor.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sectionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: sectionColor, size: 22),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.2)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}
