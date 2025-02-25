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
      print("CUSTOM_LOG: Starting to fetch user data");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      print("CUSTOM_LOG: Token available: ${token != null}");
      
      if (token == null) {
        setState(() => _isFetchingUser = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authentication token found')),
        );
        return;
      }
      
      print("CUSTOM_LOG: Preparing to make API request to ${hostApiKey}api/v1/accounts/user/");
      
      final response = await http.get(
        Uri.parse('${hostApiKey}api/v1/accounts/user/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      print("CUSTOM_LOG: Response status: ${response.statusCode}");
      print("CUSTOM_LOG: Response body preview: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}");
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userData = data['user'];
        
        if (userData != null) {
          setState(() {
            _firstNameController.text = userData['name']?.split(' ')[0] ?? '';
            _lastNameController.text = userData['name']?.split(' ').length > 1 
                ? userData['name'].split(' ')[1] 
                : '';
            _emailController.text = userData['email'] ?? '';
            _mobileController.text = userData['mobile'] ?? '';
            _existingImageUrl = userData['avatarUrl'];
            _isFetchingUser = false;
          });
          print("CUSTOM_LOG: User data loaded successfully");
        } else {
          throw Exception('User data not found in response');
        }
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      print("CUSTOM_LOG: Error fetching user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user data: $e')),
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
        request.files
            .add(await http.MultipartFile.fromPath('photo', _imageFile!.path));
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      // No bottomNavigationBar anymore as we've moved the button back to the main body
      body: _isFetchingUser
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : SafeArea(
            child: SingleChildScrollView(
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
                          fontSize: 20,
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
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  image: _imageFile != null
                                      ? DecorationImage(
                                          image: FileImage(_imageFile!),
                                          fit: BoxFit.cover)
                                      : _existingImageUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(_existingImageUrl!),
                                              fit: BoxFit.cover)
                                          : null,
                                ),
                                child: (_imageFile == null &&
                                        _existingImageUrl == null)
                                    ? const Center(
                                        child: Icon(Icons.person,
                                            size: 50, color: Colors.grey),
                                      )
                                    : Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            color: Colors.black.withOpacity(0.4),
                                          ),
                                          const Text(
                                            'CINEMA',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  radius: 16,
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt, size: 16),
                                    color: Colors.white,
                                    onPressed: _pickImage,
                                    padding: EdgeInsets.zero,
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
                      const SizedBox(height: 32),
                      // Form Fields - First Name and Last Name
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First Name Field
                          const Text(
                            'First Name',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              hintText: 'Enter your first name',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.purple),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'First name is required' : null,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Last Name Field
                          const Text(
                            'Last Name',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              hintText: 'Enter your last name',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.purple),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Last name is required' : null,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Mobile Number Field
                          const Text(
                            'Mobile Number',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _mobileController,
                            decoration: InputDecoration(
                              hintText: 'Enter your mobile number',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.purple),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Mobile number is required' : null,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Email Field
                          const Text(
                            'Email',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'Enter your email address',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.purple),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Email is required' : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            disabledBackgroundColor: Colors.purple.withOpacity(0.6),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.0,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    color: Colors.white, // Explicitly set text color to white
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 30), // Add bottom spacing
                    ],
                  ),
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