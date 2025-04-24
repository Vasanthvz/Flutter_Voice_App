import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/voice_to_text_screen.dart';
import 'screens/text_to_voice_screen.dart';
import 'screens/settings_screen.dart';
import 'services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'AI Language App',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF6366F1),
          scaffoldBackgroundColor: const Color(0xFF141420),
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: const Color(0xFF6366F1),
            secondary: const Color(0xFF818CF8),
            brightness: Brightness.dark,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E2E),
            elevation: 0,
          ),
          fontFamily: 'Roboto',
          cardTheme: const CardTheme(
            color: Color(0xFF282838),
          ),
        ),
        home: const MainMenuScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_url');
      
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _apiService.setCustomBaseUrl(savedUrl);
      } else {
        // Auto-detect appropriate URL based on platform
        String defaultUrl = '';
        if (kIsWeb) {
          defaultUrl = 'http://localhost:8002';
        } else {
          defaultUrl = 'http://10.0.2.2:8002';
        }
        _apiService.setCustomBaseUrl(defaultUrl);
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
    } finally {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Language Assistant',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(apiService: _apiService),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ))
          : Container(
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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text(
                        'Select a Feature',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildFeatureCard(
                        title: 'Voice to Text',
                        description: 'Convert speech to text using AI',
                        icon: Icons.mic,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const VoiceToTextScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureCard(
                        title: 'Text to Voice',
                        description: 'Translate text and convert to speech',
                        icon: Icons.record_voice_over,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TextToVoiceScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0xFF6366F1).withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF6366F1),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
