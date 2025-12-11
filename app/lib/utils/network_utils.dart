import 'dart:io';

class NetworkUtils {
  /// Get the local IP address of the device
  static Future<String?> getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return null;
  }

  /// Common host configurations for testing
  static const List<String> commonHosts = [
    'http://10.0.2.2:8000', // Android emulator - try this first
    'http://192.168.2.29:8000', // Current server IP
    'http://127.0.0.1:8000',
    'http://localhost:8000',
  ];

  /// Test if a host is reachable
  static Future<bool> testConnection(String baseUrl) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 2); // Shorter timeout
      client.idleTimeout = Duration(seconds: 2);

      // Try multiple endpoints
      final testEndpoints = ['/health', '/docs', '/', '/predict'];

      for (String endpoint in testEndpoints) {
        try {
          print('🔍 Testing: $baseUrl$endpoint');
          final uri = Uri.parse('$baseUrl$endpoint');
          final request = await client.getUrl(uri);
          final response = await request.close();

          print('📡 Response status: ${response.statusCode}');

          if (response.statusCode == 200 ||
              response.statusCode == 404 ||
              response.statusCode == 422) {
            // 422 is also OK for FastAPI
            client.close();
            print(' Host $baseUrl is reachable!');
            return true; // Server is responding
          }
        } catch (e) {
          print(' Endpoint $endpoint failed: $e');
          // Continue to next endpoint
          continue;
        }
      }

      client.close();
      print(' All endpoints failed for $baseUrl');
      return false;
    } catch (e) {
      print(' Connection test failed for $baseUrl: $e');
      return false;
    }
  }

  /// Find the first working host from common configurations
  static Future<String?> findWorkingHost() async {
    for (String host in commonHosts) {
      if (await testConnection(host)) {
        return host;
      }
    }
    return null;
  }
}
