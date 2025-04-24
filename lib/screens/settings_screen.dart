import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final ApiService apiService;

  const SettingsScreen({
    super.key,
    required this.apiService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverUrlController = TextEditingController();
  bool _isLoading = true;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_url');
      
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _serverUrlController.text = savedUrl;
        _currentUrl = savedUrl;
      } else {
        // Set default value based on platform
        String defaultUrl = '';
        if (kIsWeb) {
          defaultUrl = 'http://localhost:8001';
        } else {
          defaultUrl = 'http://10.0.2.2:8001';
        }
        _serverUrlController.text = defaultUrl;
        _currentUrl = defaultUrl;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newUrl = _serverUrlController.text.trim();
      if (newUrl.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('server_url', newUrl);
        
        // Update API service with new URL
        widget.apiService.setCustomBaseUrl(newUrl);
        
        setState(() {
          _currentUrl = newUrl;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1E1E2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1E2E),
              Color(0xFF141420),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 16),
                      child: Text(
                        'Server Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: const Color(0xFF282838),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Server URL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter the URL of the translation server',
                              style: TextStyle(
                                color: Color(0xFFD1D5DB),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF323248),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                              ),
                              child: TextField(
                                controller: _serverUrlController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'http://localhost:8001',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  contentPadding: const EdgeInsets.all(16),
                                  border: InputBorder.none,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
                                    onPressed: () {
                                      String defaultUrl = '';
                                      if (kIsWeb) {
                                        final origin = Uri.base.origin;
                                        defaultUrl = '$origin:8001';
                                      } else {
                                        defaultUrl = 'http://10.0.2.2:8001';
                                      }
                                      _serverUrlController.text = defaultUrl;
                                    },
                                    tooltip: 'Reset to default',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_currentUrl.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Current URL: $_currentUrl',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saveSettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 4,
                                ),
                                child: const Text(
                                  'Save Settings',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (kIsWeb)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF323248),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 20),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Web Mode',
                                          style: TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'On web, you may need to adjust the URL to match your server address. For local testing, try using "http://localhost:8001" or the current domain with ":8001" appended.',
                                      style: TextStyle(
                                        color: Color(0xFFD1D5DB),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
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
    );
  }
} 