import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_auth_data.dart';
import '../models/weather_alert.dart';

class ApiService {
  static const String baseUrl = 'http://54.251.163.39:8080/api';
  final _storage = const FlutterSecureStorage();

  Future<UserAuthData> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'idToken': idToken}),
    );

    final responseBody = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      final userAuthData = UserAuthData.fromJson(responseBody);

      await _storage.write(key: 'jwt_token', value: userAuthData.token);
      await _storage.write(key: 'user_email', value: userAuthData.email);
      await _storage.write(key: 'user_fullname', value: userAuthData.fullName);

      return userAuthData;
    } else {
      throw Exception(responseBody['message'] ?? 'Đăng nhập Google thất bại.');
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    String? token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getUserSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/settings'),
      headers: await _getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load settings');
    }
  }

  Future<List<WeatherAlert>> getCityWeatherCached() async {
    final response = await http.get(
      Uri.parse('$baseUrl/city-weather'), // Endpoint mới
      headers: await _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => WeatherAlert.fromJson(json)).toList();
    } else {
      throw Exception('Lỗi tải dữ liệu cache: ${response.statusCode}');
    }
  }

  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: await _getAuthHeaders(),
      body: jsonEncode(settings),
    );
  }
  Future<void> saveRouteLog(Map<String, dynamic> logInfo, List<dynamic> alerts) async {
    final response = await http.post(
      Uri.parse('$baseUrl/logs/save'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({
        "logInfo": logInfo,
        "alerts": alerts
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Không thể lưu lịch sử chuyến đi: ${response.body}');
    }
  }

  Future<List<dynamic>> getFavoriteRoutes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/routes/favorites'),
      headers: await _getAuthHeaders(),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      return [];
    }
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Không thể tải danh sách lộ trình ưa thích.');
    }
  }
  Future<void> createFavoriteRoute(Map<String, dynamic> routeData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/routes/favorites'),
      headers: await _getAuthHeaders(),
      body: jsonEncode(routeData),
    );
    if (response.statusCode != 201) {
      throw Exception('Không thể lưu lộ trình ưa thích.');
    }
  }
  Future<void> deleteFavoriteRoute(int routeId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/routes/favorites/$routeId'),
      headers: await _getAuthHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Không thể xóa lộ trình ưa thích.');
    }
  }

  Future<List<dynamic>> getSavedLocations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/locations'),
      headers: await _getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load saved locations');
    }
  }

  Future<List<dynamic>> getRouteHistoryLogs() async {
    final response = await http.get(
      Uri.parse('$baseUrl/logs/my-logs'),
      headers: await _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Không thể tải lịch sử chuyến đi.');
    }
  }

  Future<List<dynamic>> getWeatherForAlternativeRoutes(
      List<Map<String, dynamic>> routesData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/weather/analyze-routes'),
      headers: await _getAuthHeaders(),
      body: jsonEncode(routesData),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Không thể phân tích thời tiết cho các tuyến đường.');
    }
  }

  Future<List<dynamic>> getSearchHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/history'),
      headers: await _getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load search history');
    }
  }

  Future<void> addSearchHistory(String query) async {
    await http.post(
      Uri.parse('$baseUrl/history'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({'query': query}),
    );
  }

  Future<List<WeatherAlert>> getHourlyForecast(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('$baseUrl/weather/forecast?latitude=$lat&longitude=$lon'),
      headers: await _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> responseBody = jsonDecode(utf8.decode(response.bodyBytes));

      return responseBody.map((item) => WeatherAlert.fromJson(item)).toList();
    } else {
      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      throw Exception('Không thể tải dữ liệu dự báo.');
    }
  }

  Future<List<WeatherAlert>> getBatchWeather(Map<String, dynamic> requestBody) async {
    List<dynamic> locations = requestBody['locations'];
    if (locations.isEmpty) return [];

    List<String> points = locations.map((l) => "${l['lat']},${l['lon']}").toList();

    Map<String, dynamic> backendBody;

    if (points.length == 1) {
      backendBody = {
        "origin": points[0],
        "destination": points[0],
        "waypoints": []
      };
    } else {
      backendBody = {
        "origin": points[0],
        "destination": points.last,
        "waypoints": points.sublist(1, points.length - 1)
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/weather/check-route'),
      headers: await _getAuthHeaders(),
      body: jsonEncode(backendBody),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => WeatherAlert.fromJson(json)).toList();
    } else {
      throw Exception('Lỗi tải dữ liệu tổng thể: ${response.statusCode}');
    }
  }

  Future<String> registerUser(String fullName, String email, String password, String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({'fullName': fullName, 'email': email, 'password': password, 'phone': phone}),
    );
    final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 201) {
      return responseBody['message'] ?? "Đăng ký thành công!";
    } else {
      throw Exception(responseBody['message'] ?? 'Đăng ký thất bại!');
    }
  }

  Future<UserAuthData> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      final userAuthData = UserAuthData.fromJson(responseBody);
      await _storage.write(key: 'jwt_token', value: userAuthData.token);
      await _storage.write(key: 'user_email', value: userAuthData.email);
      await _storage.write(key: 'user_fullname', value: userAuthData.fullName);
      return userAuthData;
    } else {
      throw Exception(responseBody['message'] ?? 'Đăng nhập thất bại!');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_email');
    await _storage.delete(key: 'user_fullname');
  }

  Future<WeatherAlert> getCurrentWeather(double lat, double lon) async {
    final response = await http.post(
      Uri.parse('$baseUrl/weather/current'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({'latitude': lat, 'longitude': lon}),
    );
    if (response.statusCode == 200) {
      return WeatherAlert.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      throw Exception('Không thể tải dữ liệu thời tiết hiện tại.');
    }
  }

  Future<List<WeatherAlert>> getWeatherAlerts(Map<String, dynamic> requestBody) async {
    final response = await http.post(
      Uri.parse('$baseUrl/weather/check-route'),
      headers: await _getAuthHeaders(),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => WeatherAlert.fromJson(item)).toList();
    } else {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorBody['message'] ?? 'Không thể tải cảnh báo thời tiết.');
    }
  }
}