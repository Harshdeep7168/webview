import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'service_request_form_dialog.dart';
import 'service_request_view_dialog.dart' hide SizedBox;

class ServiceRequestsPage extends StatefulWidget {
  final Function onBack;

  const ServiceRequestsPage({
    Key? key,
    required this.onBack,
  }) : super(key: key);

  @override
  State<ServiceRequestsPage> createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;
  String? token;

  // Define API base URL as a constant
  final String hostApiUrl = 'https://dev.nova.deskos.net/';

  @override
  void initState() {
    super.initState();
    _loadToken().then((_) => _fetchRequests());
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token');
    });
  }

  Future<void> _fetchRequests() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint("Starting to fetch service requests");

      if (token == null) {
        throw Exception('No authentication token found');
      }

      debugPrint(
          "Preparing to make API request to ${hostApiUrl}api/v1/helpdesk/user/requests/");

      final response = await http.get(
        Uri.parse('${hostApiUrl}api/v1/helpdesk/user/requests/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("Response status: ${response.statusCode}");
      debugPrint(
          "Response body preview: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          requests = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
        debugPrint(
            "Service requests loaded successfully: ${data.length} requests found");
      } else {
        throw Exception('Failed to load requests: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching service requests: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load service requests: $e')),
        );
      }
    }
  }

  void _handleOpenCreate() {
    showDialog(
      context: context,
      builder: (context) => ServiceRequestFormDialog(
        onSuccess: _handleSuccess,
      ),
    );
  }

  void _handleOpenEdit(Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      builder: (context) => ServiceRequestFormDialog(
        onSuccess: _handleSuccess,
        requestData: requestData,
      ),
    );
  }

  void _handleOpenView(int requestId) {
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication token not found')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ServiceRequestViewDialog(
        requestId: requestId,
        onEdit: (Map<String, dynamic> data) {
          Navigator.of(context).pop();
          _handleOpenEdit(data);
        },
        token: token!,
      ),
    );
  }

  void _handleSuccess() {
    _fetchRequests();
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
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get activeRequests {
    return requests
        .where((request) =>
            request['status'] != null &&
            !['RESOLVED', 'CLOSED']
                .contains(request['status'].toString().toUpperCase()))
        .toList();
  }

  List<Map<String, dynamic>> get resolvedRequests {
    return requests
        .where((request) =>
            request['status'] != null &&
            ['RESOLVED', 'CLOSED']
                .contains(request['status'].toString().toUpperCase()))
        .toList();
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isActive) {
    final String statusText =
        (request['status_display'] ?? request['status'] ?? 'UNKNOWN')
            .toString();
    final String priorityText = (request['priority'] ?? 'NORMAL').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (request['id'] is int) {
            _handleOpenView(request['id']);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid request ID')),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isActive
                ? LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.red.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    request['sr_id']?.toString() ?? 'SR-XXX',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            priorityText,
                            style: TextStyle(
                              color: _getPriorityColor(priorityText),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor:
                              _getPriorityColor(priorityText).withOpacity(0.1),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      Chip(
                        label: Text(
                          statusText,
                          style: TextStyle(
                            color: _getStatusColor(request['status'] ?? ''),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor:
                            _getStatusColor(request['status'] ?? '')
                                .withOpacity(0.1),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      request['title']?.toString() ?? 'Untitled Request',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    request['category_name']?.toString() ?? 'General',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    request['created_at'] != null
                        ? DateTime.parse(request['created_at'].toString())
                            .toLocal()
                            .toString()
                            .split(' ')[0]
                        : 'Unknown date',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => widget.onBack(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Requests',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Track and manage your service requests',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _handleOpenCreate,
              icon: const Icon(Icons.add),
              label: const Text('New Request'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeRequests.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            'Active Requests',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...activeRequests
                          .map((request) => _buildRequestCard(request, true)),
                      const SizedBox(height: 24),
                    ],
                    if (resolvedRequests.isNotEmpty) ...[
                      Text(
                        'Past Requests',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      ...resolvedRequests
                          .map((request) => _buildRequestCard(request, false)),
                    ],
                    if (requests.isEmpty)
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          width: double.infinity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No service requests found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a new request to get started',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: MediaQuery.of(context).size.width < 600
          ? FloatingActionButton(
              onPressed: _handleOpenCreate,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
