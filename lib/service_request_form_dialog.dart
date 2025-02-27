import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ServiceRequestFormDialog extends StatefulWidget {
  final Function onSuccess;
  final Map<String, dynamic>? requestData;

  const ServiceRequestFormDialog({
    Key? key,
    required this.onSuccess,
    this.requestData,
  }) : super(key: key);

  @override
  State<ServiceRequestFormDialog> createState() =>
      _ServiceRequestFormDialogState();
}

class _ServiceRequestFormDialogState extends State<ServiceRequestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategory;
  String _selectedPriority = 'MEDIUM';
  bool _isSubmitting = false;
  bool _isLoading = true;
  String _errorMessage = '';

  List<Map<String, dynamic>> _categories = [];
  String? _token;

  // Host API key from environment - matching your profile_settings_page.dart
  final String hostApiKey = 'https://dev.nova.deskos.net/';

  final List<Map<String, String>> _priorityOptions = [
    {'value': 'LOW', 'label': 'Low Priority'},
    {'value': 'MEDIUM', 'label': 'Medium Priority'},
    {'value': 'HIGH', 'label': 'High Priority'},
  ];

  // final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH'];

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) => _fetchCategories());

    if (widget.requestData != null) {
      _titleController.text = widget.requestData!['title'] ?? '';
      _descriptionController.text = widget.requestData!['description'] ?? '';
      _selectedPriority = widget.requestData!['priority'] ?? 'MEDIUM';

      // Check if category is an object or just an ID
      if (widget.requestData!['category'] is Map) {
        _selectedCategory = widget.requestData!['category']['id'].toString();
      } else {
        _selectedCategory = widget.requestData!['category'].toString();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
    });
  }

  Future<bool> saveActiveCampus(Map<String, dynamic> campus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final campusJson = json.encode(campus);
      print(
          "CUSTOM_LOG: Saving activeCampus to SharedPreferences: $campusJson");
      final result = await prefs.setString('activeCampus', campusJson);
      print("CUSTOM_LOG: Save result: $result");
      return result;
    } catch (error) {
      print(
          "CUSTOM_LOG: Error saving activeCampus to SharedPreferences: $error");
      return false;
    }
  }

// Function to get active campus from SharedPreferences
  Future<Map<String, dynamic>?> getActiveCampus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Debug: Print all available keys in SharedPreferences
      print("CUSTOM_LOG: All SharedPreferences keys: ${prefs.getKeys()}");

      final savedCampus = prefs.getString('activeCampus');
      print("CUSTOM_LOG: Raw activeCampus value: $savedCampus");

      if (savedCampus != null && savedCampus.isNotEmpty) {
        final activeCampus = json.decode(savedCampus);
        print("CUSTOM_LOG: Successfully parsed activeCampus: $activeCampus");
        return activeCampus;
      } else {
        // For testing purposes, let's add a default campus if none is found
        final defaultCampus = {
          "id": 2,
          "name": "campus-12",
          "address": "123/dd",
          "lat": 1,
          "lon": 1
        };

        // Save this default campus to SharedPreferences
        await saveActiveCampus(defaultCampus);
        print("CUSTOM_LOG: No activeCampus found, saved default campus");

        return defaultCampus;
      }
    } catch (error) {
      print(
          "CUSTOM_LOG: Error retrieving activeCampus from SharedPreferences: $error");
      return null;
    }
  }

  Future<void> _fetchCategories() async {
    try {
      print("CUSTOM_LOG: Starting to fetch categories");

      if (_token == null) {
        throw Exception('No authentication token found');
      }

      // Get active campus using the separate function
      Map<String, dynamic>? activeCampus = await getActiveCampus();
      int? campusId = activeCampus?['id'];

      // Debug logging
      if (campusId != null) {
        print("CUSTOM_LOG: Using campus ID from SharedPreferences: $campusId");
      } else {
        // If no campus is found or ID is null, default to campus ID 2
        campusId = 2;
        print("CUSTOM_LOG: No valid campus ID found, using default: $campusId");
      }

      // Build the complete URL with query parameters
      final uri = Uri.parse('${hostApiKey}api/v1/helpdesk/user/categories/')
          .replace(queryParameters: {'campus_id': campusId.toString()});

      print("CUSTOM_LOG: Preparing to make API request to $uri");

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      // Rest of your code remains the same
      print("CUSTOM_LOG: Response status: ${response.statusCode}");
      print(
          "CUSTOM_LOG: Response body preview: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
          _isLoading = false;

          // If editing and we have the category, make sure it's selected
          if (widget.requestData != null &&
              widget.requestData!['category'] != null) {
            if (widget.requestData!['category'] is Map) {
              _selectedCategory =
                  widget.requestData!['category']['id'].toString();
            } else {
              _selectedCategory = widget.requestData!['category'].toString();
            }
          } else if (_categories.isNotEmpty) {
            // Set default category
            _selectedCategory = _categories.first['id'].toString();
          }
        });
        print(
            "CUSTOM_LOG: Categories loaded successfully: ${data.length} categories found");
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print("CUSTOM_LOG: Error fetching categories: $e");
      setState(() {
        _errorMessage = 'Failed to load categories. Please try again.';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Authentication error. Please login again.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final url = widget.requestData != null
          ? 'https://demo.deskos.net/api/v1/helpdesk/user/requests/${widget.requestData!['id']}/'
          : 'https://demo.deskos.net/api/v1/helpdesk/user/requests/';

      final method = widget.requestData != null ? 'PUT' : 'POST';

      final Map<String, dynamic> requestBody = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': int.parse(_selectedCategory!),
        'priority': _selectedPriority,
      };

      // Log the request data
      print("CUSTOM_LOG: Sending request to: $url");
      print("CUSTOM_LOG: Request method: $method");
      print("CUSTOM_LOG: Request body: ${jsonEncode(requestBody)}");
      print(
          "CUSTOM_LOG: Request headers: Bearer token (hidden) and Content-Type: application/json");

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Log the response
      print("CUSTOM_LOG: Response: ${response.statusCode}");
      print("CUSTOM_LOG: Response headers: ${response.headers}");
      print("CUSTOM_LOG: Response body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("CUSTOM_LOG: Form submitted successfully");
        widget.onSuccess();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.requestData != null
                  ? 'Request updated successfully'
                  : 'Request created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Log more details about the error
        print("CUSTOM_LOG: Error response status: ${response.statusCode}");
        print("CUSTOM_LOG: Error response body: ${response.body}");
        throw Exception(
            'Failed to ${widget.requestData != null ? 'update' : 'create'} request: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("CUSTOM_LOG: Error submitting form: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to ${widget.requestData != null ? 'update' : 'create'} request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width > 600
            ? 500
            : MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.requestData != null
                            ? 'Edit Service Request'
                            : 'Create Service Request',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (widget.requestData != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.edit, color: Colors.purple),
                              ),
                            Text(
                              widget.requestData != null
                                  ? 'Edit Service Request'
                                  : 'Create Service Request',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          color: Colors.grey[500],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: Colors.red[700], size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _errorMessage = '';
                                });
                              },
                            )
                          ],
                        ),
                      ),

                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'Brief description of the issue',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.purple),
                        ),
                      ),
                      enabled: !_isSubmitting,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Detailed explanation of the problem',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.purple),
                        ),
                        alignLabelWithHint: true,
                      ),
                      enabled: !_isSubmitting,
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.purple),
                        ),
                      ),
                      items: _priorityOptions.map((option) {
                        Color priorityColor;
                        switch (option['value']) {
                          case 'HIGH':
                            priorityColor = Colors.red;
                            break;
                          case 'MEDIUM':
                            priorityColor = Colors.orange;
                            break;
                          case 'LOW':
                            priorityColor = Colors.green;
                            break;
                          default:
                            priorityColor = Colors.blue;
                        }

                        return DropdownMenuItem<String>(
                          value: option['value'],
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: priorityColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(option['label']!),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              setState(() {
                                _selectedPriority = value!;
                              });
                            },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.purple),
                        ),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'].toString(),
                          child: Row(
                            children: [
                              Text(category['name']),
                              if (category['campus'] != null &&
                                  category['campus'] is Map)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    ' - ${category['campus']['name']}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _isSubmitting || _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          disabledBackgroundColor:
                              Colors.purple.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.requestData != null
                                    ? 'Update Request'
                                    : 'Submit Request',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
