import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isFetchingUser = true;
  
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  // Host API key from environment
  final String hostApiKey = 'https://dev.nova.deskos.net/';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // Get your stored token

      final response = await http.get(
        Uri.parse('${hostApiKey}api/v1/accounts/user/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body)['user'];
        setState(() {
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _mobileController.text = userData['mobile'] ?? '';
          _existingImageUrl = userData['avatarUrl'];
          _isFetchingUser = false;
        });
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user data')),
      );
      setState(() => _isFetchingUser = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() => _imageFile = File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${hostApiKey}api/v1/accounts/user/update-general-settings/'),
      );

      request.fields['firstName'] = _firstNameController.text;
      request.fields['lastName'] = _lastNameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['mobileNumber'] = _mobileController.text;

      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', _imageFile!.path));
      }

      request.headers['Authorization'] = 'Bearer $token';

      final response = await request.send();
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile Settings', 
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: _isFetchingUser 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Profile Image Section
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _imageFile != null 
                                ? FileImage(_imageFile!) 
                                : _existingImageUrl != null 
                                  ? NetworkImage('$hostApiKey$_existingImageUrl') as ImageProvider
                                  : null,
                              child: (_imageFile == null && _existingImageUrl == null)
                                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                backgroundColor: Colors.purple,
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  color: Colors.white,
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Allowed *.jpeg, *.jpg, *.png, *.gif\nmax size of 3.1MB',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Form Fields
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) => 
                              value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) => 
                              value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) => 
                        value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => 
                        value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }
}