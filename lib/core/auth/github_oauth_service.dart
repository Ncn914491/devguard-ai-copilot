import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';
import 'package:universal_io/io.dart';

/// GitHub OAuth service for handling authentication flow
class GitHubOAuthService {
  static final GitHubOAuthService _instance = GitHubOAuthService._internal();
  static GitHubOAuthService get instance => _instance;
  GitHubOAuthService._internal();

  String? _clientId;
  String? _clientSecret;
  String? _redirectUri;
  
  /// Initialize the GitHub OAuth service
  void initialize() {
    _clientId = dotenv.env['GITHUB_CLIENT_ID'];
    _clientSecret = dotenv.env['GITHUB_CLIENT_SECRET'];
    _redirectUri = dotenv.env['GITHUB_OAUTH_REDIRECT_URI'] ?? 
                   'http://localhost:8080/auth/github/callback';
    
    if (_clientId == null || _clientSecret == null) {
      print('Warning: GitHub OAuth credentials not configured');
    }
  }

  /// Generate OAuth authorization URL
  String generateAuthUrl() {
    if (_clientId == null) {
      throw Exception('GitHub OAuth not configured');
    }

    final state = _generateState();
    final scope = 'user:email';
    
    final params = {
      'client_id': _clientId!,
      'redirect_uri': _redirectUri!,
      'scope': scope,
      'state': state,
      'allow_signup': 'true',
    };

    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://github.com/login/oauth/authorize?$query';
  }

  /// Exchange authorization code for access token
  Future<String?> exchangeCodeForToken(String code, String state) async {
    if (_clientId == null || _clientSecret == null) {
      throw Exception('GitHub OAuth not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('https://github.com/login/oauth/access_token'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': _clientId!,
          'client_secret': _clientSecret!,
          'code': code,
          'redirect_uri': _redirectUri!,
          'state': state,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['error'] != null) {
          print('GitHub OAuth error: ${data['error_description']}');
          return null;
        }
        
        return data['access_token'];
      }
      
      return null;
    } catch (e) {
      print('Error exchanging code for token: $e');
      return null;
    }
  }

  /// Get user information from GitHub API
  Future<Map<String, dynamic>?> getUserInfo(String accessToken) async {
    try {
      // Get user profile
      final userResponse = await http.get(
        Uri.parse('https://api.github.com/user'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'DevGuard-AI-Copilot',
        },
      );

      if (userResponse.statusCode != 200) {
        print('Failed to get user info: ${userResponse.statusCode}');
        return null;
      }

      final userData = jsonDecode(userResponse.body);

      // Get user email if not public
      if (userData['email'] == null) {
        final emailResponse = await http.get(
          Uri.parse('https://api.github.com/user/emails'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'DevGuard-AI-Copilot',
          },
        );

        if (emailResponse.statusCode == 200) {
          final emails = jsonDecode(emailResponse.body) as List;
          final primaryEmail = emails.firstWhere(
            (email) => email['primary'] == true,
            orElse: () => emails.isNotEmpty ? emails.first : null,
          );
          if (primaryEmail != null) {
            userData['email'] = primaryEmail['email'];
          }
        }
      }

      return userData;
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }

  /// Start OAuth flow for web platform
  Future<String?> startWebOAuthFlow() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // For desktop platforms, we need to open browser and handle callback
      return await _startDesktopOAuthFlow();
    } else {
      // For web platform, redirect to GitHub
      final authUrl = generateAuthUrl();
      // In a real web implementation, you would redirect to this URL
      // For now, return the URL for manual handling
      return authUrl;
    }
  }

  /// Handle OAuth callback (for web/desktop)
  Future<String?> handleCallback(String callbackUrl) async {
    final uri = Uri.parse(callbackUrl);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      print('OAuth error: $error');
      return null;
    }

    if (code == null || state == null) {
      print('Missing code or state in callback');
      return null;
    }

    return await exchangeCodeForToken(code, state);
  }

  /// Start OAuth flow for desktop platforms
  Future<String?> _startDesktopOAuthFlow() async {
    try {
      // Create a temporary HTTP server to handle the callback
      final server = await HttpServer.bind('localhost', 8080);
      final authUrl = generateAuthUrl();
      
      print('Opening browser for GitHub OAuth...');
      print('Auth URL: $authUrl');
      
      // In a real implementation, you would open the browser here
      // For now, we'll simulate the process
      
      // Listen for the callback
      final completer = Completer<String?>();
      
      server.listen((request) async {
        if (request.uri.path == '/auth/github/callback') {
          final code = request.uri.queryParameters['code'];
          final state = request.uri.queryParameters['state'];
          
          if (code != null && state != null) {
            final token = await exchangeCodeForToken(code, state);
            completer.complete(token);
          } else {
            completer.complete(null);
          }
          
          // Send response to browser
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('''
              <html>
                <body>
                  <h1>Authentication ${code != null ? 'Successful' : 'Failed'}</h1>
                  <p>You can close this window.</p>
                  <script>window.close();</script>
                </body>
              </html>
            ''');
          await request.response.close();
          await server.close();
        }
      });
      
      // Timeout after 5 minutes
      Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) {
          completer.complete(null);
          server.close();
        }
      });
      
      return await completer.future;
    } catch (e) {
      print('Error in desktop OAuth flow: $e');
      return null;
    }
  }

  /// Generate a random state parameter for OAuth security
  String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Check if GitHub OAuth is configured
  bool get isConfigured => _clientId != null && _clientSecret != null;
}