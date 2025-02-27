import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ServiceRequestViewDialog extends StatefulWidget {
  final int requestId;
  final Function(Map<String, dynamic>) onEdit;
  final String? token;
  final bool minimal;

  const ServiceRequestViewDialog({
    Key? key,
    required this.requestId,
    required this.onEdit,
    this.token,
    this.minimal = false,
  }) : super(key: key);

  @override
  State<ServiceRequestViewDialog> createState() =>
      _ServiceRequestViewDialogState();
}

class _ServiceRequestViewDialogState extends State<ServiceRequestViewDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _attachments = [];
  String? _token;

  // Host API key from environment - matching your profile_settings_page.dart
  final String hostApiKey = 'https://dev.nova.deskos.net/';

  // Tabs
  late TabController _tabController;
  int _activeTab = 0;

  // New comment
  final TextEditingController _commentController = TextEditingController();
  bool _sendingComment = false;

  // File attachment
  File? _file;
  bool _isUploading = false;
  bool _uploadSuccess = false;

  // Confirmation dialog
  bool _showConfirmClose = false;
  bool _isSubmitting = false;

  // Error state
  String _errorMessage = '';

  // Image preview
  bool _previewOpen = false;
  String _previewImageUrl = '';
  String _previewImageName = '';

  // Deleting attachment or comment
  int? _deletingAttachmentId;
  int? _deletingCommentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _activeTab = _tabController.index;
        });
      }
    });

    _token = widget.token;
    if (_token == null) {
      _loadToken().then((_) => _fetchRequestDetails());
    } else {
      _fetchRequestDetails();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = prefs.getString('token');
      });
    }
  }

  Future<void> _fetchRequestDetails() async {
    if (_token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Authentication error. Please login again.')),
        );
      }
      return;
    }

    try {
      debugPrint(
          "Starting to fetch service request details for ID: ${widget.requestId}");

      // Fetch request details
      final response = await http.get(
        Uri.parse(
            '${hostApiKey}api/v1/helpdesk/user/requests/${widget.requestId}/'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _requestData = data;

            // Extract comments, history, and attachments if they exist in the response
            if (data.containsKey('comments') && data['comments'] is List) {
              _comments = List<Map<String, dynamic>>.from(data['comments']);
            }

            if (data.containsKey('history') && data['history'] is List) {
              _history = List<Map<String, dynamic>>.from(data['history']);
            }

            if (data.containsKey('attachments') &&
                data['attachments'] is List) {
              _attachments =
                  List<Map<String, dynamic>>.from(data['attachments']);
            }

            _isLoading = false;
          });
        }
        debugPrint("Request details loaded successfully");
      } else {
        throw Exception(
            'Failed to load request details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching request details: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load request details. Please try again.';
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load request details: $e')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_token == null || _commentController.text.trim().isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _sendingComment = true;
      });
    }

    try {
      debugPrint("Adding comment to request ID: ${widget.requestId}");

      final response = await http.post(
        Uri.parse(
            '${hostApiKey}api/v1/helpdesk/user/requests/${widget.requestId}/comments/'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': _commentController.text,
          'is_internal': false,
        }),
      );

      debugPrint("Comment response status: ${response.statusCode}");

      if (response.statusCode == 201) {
        debugPrint("Comment added successfully");
        _commentController.clear();
        // Refresh the data
        _fetchRequestDetails();
      } else {
        throw Exception('Failed to add comment: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error adding comment: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to add comment. Please try again.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingComment = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        setState(() {
          _file = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select file: $e')),
        );
      }
    }
  }

  Future<void> _uploadFile() async {
    if (_file == null || _token == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isUploading = true;
        _uploadSuccess = false;
      });
    }

    try {
      debugPrint("Uploading attachment for request ID: ${widget.requestId}");

      // Create a multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${hostApiKey}api/v1/helpdesk/user/requests/${widget.requestId}/attachments/'),
      );

      // Add the file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        _file!.path,
      ));

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $_token';

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint("Attachment upload response status: ${response.statusCode}");

      if (response.statusCode == 201) {
        debugPrint("Attachment uploaded successfully");
        if (mounted) {
          setState(() {
            _file = null;
            _uploadSuccess = true;
          });
        }

        // Refresh the data
        _fetchRequestDetails();

        // Hide success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _uploadSuccess = false;
            });
          }
        });
      } else {
        throw Exception('Failed to upload attachment: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error uploading attachment: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to upload attachment. Please try again.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload attachment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteAttachment(int attachmentId) async {
    if (_token == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _deletingAttachmentId = attachmentId;
      });
    }

    try {
      debugPrint("Deleting attachment ID: $attachmentId");

      final response = await http.delete(
        Uri.parse(
            '${hostApiKey}api/v1/helpdesk/user/requests/${widget.requestId}/attachments/$attachmentId/delete/'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("Delete attachment response status: ${response.statusCode}");

      if (response.statusCode == 204 || response.statusCode == 200) {
        debugPrint("Attachment deleted successfully");
        // Refresh the data
        _fetchRequestDetails();
      } else {
        throw Exception('Failed to delete attachment: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error deleting attachment: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to delete attachment. Please try again.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete attachment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingAttachmentId = null;
        });
      }
    }
  }

  Future<void> _deleteComment(int commentId) async {
    if (_token == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _deletingCommentId = commentId;
      });
    }

    try {
      debugPrint("Deleting comment ID: $commentId");

      final response = await http.delete(
        Uri.parse(
            '${hostApiKey}api/v1/helpdesk/user/requests/${widget.requestId}/comments/$commentId/delete/'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("Delete comment response status: ${response.statusCode}");

      if (response.statusCode == 204 || response.statusCode == 200) {
        debugPrint("Comment deleted successfully");
        // Refresh the data
        _fetchRequestDetails();
      } else {
        throw Exception('Failed to delete comment: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error deleting comment: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to delete comment. Please try again.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingCommentId = null;
        });
      }
    }
  }

  Future<void> _closeRequest() async {
    if (_token == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

    try {
      debugPrint("Closing request ID: ${widget.requestId}");

      final response = await http.delete(
        Uri.parse(
            '${hostApiKey}api/v1/helpdesk/user/requests/${widget.requestId}/'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("Close request response status: ${response.statusCode}");

      if (response.statusCode == 204 || response.statusCode == 200) {
        debugPrint("Request closed successfully");
        if (mounted) {
          setState(() {
            _showConfirmClose = false;
          });
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Failed to close request: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error closing request: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to close request. Please try again.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close request: $e')),
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

  void _showImagePreview(String url, String filename) {
    if (mounted) {
      setState(() {
        _previewImageUrl = url;
        _previewImageName = filename;
        _previewOpen = true;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget _buildHeader() {
    final String statusText =
        (_requestData?['status_display'] ?? _requestData?['status'] ?? '')
            .toString();
    final String priorityText =
        (_requestData?['priority_display'] ?? _requestData?['priority'] ?? '')
            .toString();
    final String categoryText =
        (_requestData?['category_name'] ?? 'General').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _requestData?['title']?.toString() ?? 'Untitled Request',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              _requestData?['sr_id']?.toString() ?? 'SR-XXX',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              label: Text(
                statusText,
                style: TextStyle(
                  color: _getStatusColor(statusText),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: _getStatusColor(statusText).withOpacity(0.1),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Chip(
              label: Text(
                priorityText,
                style: TextStyle(
                  color: _getPriorityColor(priorityText),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: _getPriorityColor(priorityText).withOpacity(0.1),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Chip(
              label: Text(
                categoryText,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetails() {
    final description =
        _requestData?['description']?.toString() ?? 'No description provided.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          color: Colors.purple.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              description,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Attachments card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attachments',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                // File upload controls
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Select File'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_file != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _file!.path.split('/').last,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadFile,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.upload, size: 16),
                          label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_uploadSuccess) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green[700], size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'File uploaded successfully!',
                          style: TextStyle(
                              color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // List of attachments
                if (_attachments.isNotEmpty) ...[
                  ..._attachments
                      .map((attachment) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                // File icon or preview
                                if (attachment['file_type']
                                        ?.toString()
                                        .startsWith('image/') ==
                                    true) ...[
                                  GestureDetector(
                                    onTap: () => _showImagePreview(
                                        attachment['file_url']?.toString() ??
                                            '',
                                        attachment['filename']?.toString() ??
                                            'image'),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(4),
                                        image: DecorationImage(
                                          image: NetworkImage(
                                              attachment['file_url']
                                                      ?.toString() ??
                                                  ''),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.insert_drive_file,
                                        color: Colors.grey),
                                  ),
                                ],
                                const SizedBox(width: 12),

                                // Filename and actions
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        attachment['filename']?.toString() ??
                                            'File',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          TextButton.icon(
                                            onPressed: () {
                                              // Open the download URL in browser
                                              // Note: In a real app, you'd use url_launcher package
                                            },
                                            icon: const Icon(Icons.download,
                                                size: 16),
                                            label: const Text('Download'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.purple,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (_requestData?['requester']
                                                  ?['id'] ==
                                              attachment['user']?['id']) ...[
                                            TextButton.icon(
                                              onPressed:
                                                  _deletingAttachmentId ==
                                                          attachment['id']
                                                      ? null
                                                      : () => _deleteAttachment(
                                                          int.parse(
                                                              attachment['id']
                                                                  .toString())),
                                              icon: _deletingAttachmentId ==
                                                      attachment['id']
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.red,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.delete_outline,
                                                      size: 16),
                                              label: Text(
                                                  _deletingAttachmentId ==
                                                          attachment['id']
                                                      ? 'Deleting...'
                                                      : 'Delete'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ] else ...[
                  Center(
                    child: Text(
                      'No attachments yet',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Request details grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          childAspectRatio: 3,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          padding: EdgeInsets.zero,
          children: [
            _buildInfoItem(
                'Created By',
                _requestData?['requester']?['full_name']?.toString() ??
                    'Unknown'),
            _buildInfoItem('Created At',
                _formatDateTime(_requestData?['created_at']?.toString() ?? '')),
            if (_requestData?['assignee'] != null)
              _buildInfoItem(
                  'Assigned To',
                  _requestData?['assignee']?['full_name']?.toString() ??
                      'Unassigned'),
            if (_requestData?['due_date'] != null)
              _buildInfoItem('Due Date',
                  _formatDate(_requestData?['due_date']?.toString() ?? '')),
          ],
        ),

        const SizedBox(height: 24),

        // History section
        if (_history.isNotEmpty) ...[
          const Text(
            'History',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          ..._history
              .map((event) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[200],
                                child: Text(
                                  (event['user']?['full_name']?.toString() ??
                                              '?')
                                          .isNotEmpty
                                      ? (event['user']?['full_name']
                                              as String)[0]
                                          .toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['user']?['full_name']?.toString() ??
                                        'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _formatDateTime(
                                        event['created_at']?.toString() ?? ''),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            event['change_type'] == 'CREATE'
                                ? 'Created the request'
                                : 'Changed ${event['field_name']?.toString().toLowerCase() ?? ''} from ${event['old_value']?.toString() ?? 'none'} to ${event['new_value']?.toString() ?? ''}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ],
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildComments() {
    return Column(
      children: [
        // Comment input
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  maxLines: 3,
                  enabled: !_sendingComment,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: (_commentController.text.trim().isEmpty ||
                              _sendingComment)
                          ? null
                          : _addComment,
                      icon: _sendingComment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, size: 16),
                      label: Text(_sendingComment ? 'Sending...' : 'Send'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Comments list
        if (_comments.isNotEmpty) ...[
          ..._comments
              .map((comment) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                    color: comment['is_internal'] == true
                        ? Colors.orange.withOpacity(0.05)
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: comment['user']
                                            ?['avatarUrl'] !=
                                        null
                                    ? NetworkImage(
                                        comment['user']['avatarUrl'].toString())
                                    : null,
                                child: comment['user']?['avatarUrl'] == null
                                    ? Text(
                                        (comment['user']?['full_name']
                                                        ?.toString() ??
                                                    '?')
                                                .isNotEmpty
                                            ? (comment['user']?['full_name']
                                                    as String)[0]
                                                .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment['user']?['full_name']
                                              ?.toString() ??
                                          'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(
                                          comment['created_at']?.toString() ??
                                              ''),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (comment['is_internal'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.orange),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Internal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              if (comment['user']?['id'] ==
                                  _requestData?['requester']?['id'])
                                IconButton(
                                  icon: _deletingCommentId == comment['id']
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.red,
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline,
                                          size: 18),
                                  color: Colors.red,
                                  onPressed: _deletingCommentId == comment['id']
                                      ? null
                                      : () => _deleteComment(
                                          int.parse(comment['id'].toString())),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            comment['content']?.toString() ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ] else ...[
          Center(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Icon(Icons.chat_bubble_outline,
                    size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No comments yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Unknown date';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Stack(
      children: [
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width > 600
                ? 700
                : MediaQuery.of(context).size.width * 0.95,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: _isLoading
                ? Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Loading Service Request',
                              style: TextStyle(
                                fontSize: 18,
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
                            child: CircularProgressIndicator(
                                color: Colors.purple)),
                        const SizedBox(height: 16),
                      ],
                    ),
                  )
                : _requestData == null
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Request Not Found',
                                  style: TextStyle(
                                    fontSize: 18,
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
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'We couldn\'t find the requested service ticket',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dialog title
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Service Request Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(context).pop(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildHeader(),
                          ),

                          // Tab bar
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: Colors.purple,
                              unselectedLabelColor: Colors.grey[700],
                              indicatorColor: Colors.purple,
                              labelStyle:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              tabs: const [
                                Tab(
                                  icon: Icon(Icons.description),
                                  text: 'Details',
                                  iconMargin: EdgeInsets.only(bottom: 4),
                                ),
                                Tab(
                                  icon: Icon(Icons.comment),
                                  text: 'Comments',
                                  iconMargin: EdgeInsets.only(bottom: 4),
                                ),
                              ],
                            ),
                          ),

                          // Tab content
                          Expanded(
                            child: Container(
                              color: Colors.grey[50],
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // Details tab
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: _buildDetails(),
                                  ),

                                  // Comments tab
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: _buildComments(),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom buttons
                          if (_requestData != null &&
                              !['RESOLVED', 'CLOSED'].contains(
                                  _requestData!['status']
                                      ?.toString()
                                      .toUpperCase())) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!widget.minimal) ...[
                                    OutlinedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => setState(
                                              () => _showConfirmClose = true),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side:
                                            const BorderSide(color: Colors.red),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                      ),
                                      child: const Text('Close Request'),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                    ),
                                    child: const Text('Close'),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!widget.minimal) ...[
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          widget.onEdit(_requestData!),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Edit Request'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ),

        // Confirm close dialog
        if (_showConfirmClose)
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Close Request',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Are you sure you want to close this request? This action cannot be undone.',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _showConfirmClose = false),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _closeRequest,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.close, size: 16),
                        label: Text(
                            _isSubmitting ? 'Closing...' : 'Close Request'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Image preview
        if (_previewOpen)
          Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _previewOpen = false),
                  child: Image.network(
                    _previewImageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() => _previewOpen = false),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
