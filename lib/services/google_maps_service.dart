import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleMapsService {
  final String apiKey;

  GoogleMapsService(this.apiKey);

  Future<Map<String, dynamic>> getDirections(
      String origin, String destination, String travelMode) async {

    Map<String, dynamic> responseData = await _makeRequest(origin, destination, travelMode);

    if (responseData['status'] == 'ZERO_RESULTS' && responseData.containsKey('available_travel_modes')) {

      List<String> availableModes = List<String>.from(responseData['available_travel_modes']);

      if (availableModes.contains('DRIVING')) {
        print('Phương thức di chuyển bằng "$travelMode" hiện không có sẵn, và sẽ chuyển sang phương thức di chuyển khác.');

        Map<String, dynamic> fallbackResponseData = await _makeRequest(origin, destination, 'driving');

        if (fallbackResponseData['status'] == 'OK') {
          fallbackResponseData['warning_message'] = 'Không tìm thấy tuyến đường cho xe máy/xe đạp. Đã hiển thị chỉ đường cho ô tô.';
          return fallbackResponseData;
        }
      }
    }

    return responseData;
  }

  Future<Map<String, dynamic>> _makeRequest(String origin, String destination, String travelMode) async {
    final String googleTravelMode = (travelMode == 'cycling') ? 'bicycling' : travelMode;
    final String baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

    final Map<String, String> queryParameters = {
      'origin': origin,
      'destination': destination,
      'key': apiKey,
      'language': 'vi',
      'mode': googleTravelMode,
      'alternatives': 'true',
    };

    final Uri uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', queryParameters);
    print('Requesting Google Directions URL: $uri');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      print('Google Directions API failed with status: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Không thể lấy chỉ đường từ Google Maps');
    }
  }
}