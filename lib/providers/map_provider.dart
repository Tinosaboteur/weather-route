import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/palettes.dart';
import '../models/weather_alert.dart';
import '../services/api_service.dart';
import '../services/google_maps_service.dart';
import '../services/navigation_service.dart';
import '../utils/helper.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mp;
import 'package:flutter/services.dart' show rootBundle;

class MapProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  late final GoogleMapsService _googleMapsService;
  final NavigationService _navigationService = NavigationService();

  GoogleMapController? mapController;
  final CustomInfoWindowController customInfoWindowController = CustomInfoWindowController();

  List<Map<String, dynamic>> _routes = [];
  int _selectedRouteIndex = 0;
  int _recommendedRouteIndex = -1;
  bool _isRouteConfirmed = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showLegend = false;
  bool _isInitialized = false;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};

  bool _isCityOverlayVisible = false;
  String _overlayType = 'temp';
  Set<Polygon> _boundaryPolygons = {};
  Set<Polygon> _overlayGridPolygons = {};
  bool _isOverlayLoading = false;
  List<List<mp.LatLng>> _hcmBoundaryPoints = [];

  List<WeatherAlert> _weatherAlerts = [];
  Map<String, BitmapDescriptor> _customIcons = {};
  List<String> _destSuggestions = [];
  bool _originAutoSetDone = false;
  List<dynamic> _savedLocations = [];
  List<dynamic> _searchHistory = [];
  LatLng? _destinationForNav;
  bool _isNavigating = false;
  Timer? _weatherRefreshTimer;
  Map<String, dynamic>? _currentRouteContext;
  List<dynamic> _favoriteRoutes = [];
  bool _trafficEnabled = false;

  Set<Circle> _overlayGridCircles = {};
  List<Map<String, dynamic>> get routes => _routes;
  int get selectedRouteIndex => _selectedRouteIndex;
  int get recommendedRouteIndex => _recommendedRouteIndex;
  bool get hasRoutes => _routes.isNotEmpty;
  bool get isRouteConfirmed => _isRouteConfirmed;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get showLegend => _showLegend;

  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  Set<Circle> get circles => _circles.union(_overlayGridCircles);

  Set<Polygon> get allPolygons => _boundaryPolygons;

  List<String> get destSuggestions => _destSuggestions;
  List<dynamic> get savedLocations => _savedLocations;
  List<dynamic> get searchHistory => _searchHistory;
  LatLng? get destinationForNav => _destinationForNav;
  bool get isNavigating => _isNavigating;
  List<dynamic> get favoriteRoutes => _favoriteRoutes;
  bool get trafficEnabled => _trafficEnabled;

  bool get isCityOverlayVisible => _isCityOverlayVisible;
  String get overlayType => _overlayType;
  bool get isOverlayLoading => _isOverlayLoading;

  MapProvider() {
    _googleMapsService = GoogleMapsService("key ");
  }

  final CameraPosition initialCameraPosition = const CameraPosition(
    target: LatLng(10.7769, 106.7009),
    zoom: 11.0,
  );

  @override
  void dispose() {
    mapController?.dispose();
    customInfoWindowController.dispose();
    _weatherRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    await loadCustomIcons();
    await _loadGeoJsonBoundary();
    _isInitialized = true;
  }

  void setMapController(GoogleMapController controller) {
    mapController = controller;
    customInfoWindowController.googleMapController = controller;
  }

  void toggleTrafficLayer() {
    _trafficEnabled = !_trafficEnabled;
    notifyListeners();
  }

  void toggleCityOverlay(String type) {
    if (_isCityOverlayVisible && _overlayType == type) {
      _isCityOverlayVisible = false;
      _overlayGridCircles.clear();
      notifyListeners();
    } else {
      _isCityOverlayVisible = true;
      _overlayType = type;
      _fetchAndDrawCityOverlay();
    }
  }

  Future<void> _fetchAndDrawCityOverlay() async {
    _isOverlayLoading = true;
    _overlayGridCircles.clear();
    notifyListeners();

    try {
      final List<WeatherAlert> rawData = await _apiService.getCityWeatherCached();

      if (rawData.isEmpty) return;

      final List<WeatherAlert> interpolatedData = _generateInterpolatedPoints(rawData, 0.045);

      Set<Circle> newCircles = {};

      const double radius = 4000.0;

      for (int i = 0; i < interpolatedData.length; i++) {
        final alert = interpolatedData[i];
        final parts = alert.location.split(',');
        final lat = double.parse(parts[0]);
        final lon = double.parse(parts[1]);

        final mpCenter = mp.LatLng(lat, lon);

        bool isInside = false;
        for (var boundary in _hcmBoundaryPoints) {
          if (mp.PolygonUtil.containsLocation(mpCenter, boundary, false)) {
            isInside = true;
            break;
          }
        }
        if (!isInside) continue;

        Color baseColor;
        if (_overlayType == 'temp') {
          baseColor = WeatherPalettes.getColorForTemp(alert.temp);
        } else {
          baseColor = WeatherPalettes.getColorForRain(alert.precip);
        }

        if (baseColor == Colors.transparent) continue;

        newCircles.add(Circle(
          circleId: CircleId("inter_circle_$i"),
          center: LatLng(lat, lon),
          radius: radius,
          fillColor: baseColor.withOpacity(0.3),
          strokeColor: Colors.transparent,
          strokeWidth: 0,
          consumeTapEvents: false,
          zIndex: 1,
        ));
      }
      _overlayGridCircles = newCircles;
    } catch (e) {
      print("❌ Lỗi overlay: $e");
      _errorMessage = "Không thể tải dữ liệu tổng thể.";
    } finally {
      _isOverlayLoading = false;
      notifyListeners();
    }
  }

  List<WeatherAlert> _generateInterpolatedPoints(List<WeatherAlert> sources, double step) {
    List<WeatherAlert> result = [];

    double minLat = 1000, maxLat = -1000, minLon = 1000, maxLon = -1000;

    List<Map<String, dynamic>> parsedSources = [];
    for (var item in sources) {
      final parts = item.location.split(',');
      final lat = double.parse(parts[0]);
      final lon = double.parse(parts[1]);
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;

      parsedSources.add({
        'lat': lat,
        'lon': lon,
        'temp': item.temp,
        'precip': item.precip
      });
    }

    minLat -= 0.02; maxLat += 0.02;
    minLon -= 0.02; maxLon += 0.02;

    const double influenceRadiusSq = 0.0225;

    for (double lat = minLat; lat <= maxLat; lat += step) {
      for (double lon = minLon; lon <= maxLon; lon += step) {

        double numeratorTemp = 0;
        double numeratorPrecip = 0;
        double denominator = 0;

        for (var source in parsedSources) {
          final sLat = source['lat'] as double;
          final sLon = source['lon'] as double;

          double distSq = (lat - sLat) * (lat - sLat) + (lon - sLon) * (lon - sLon);

          if (distSq < influenceRadiusSq) {
            double weight = 1.0 / (distSq + 0.00001);

            numeratorTemp += (source['temp'] as double) * weight;
            numeratorPrecip += (source['precip'] as double) * weight;
            denominator += weight;
          }
        }

        if (denominator > 0) {
          result.add(WeatherAlert(
              location: "$lat,$lon",
              message: "",
              alertType: "interpolated",
              icon: "unknown",
              eventTime: "",
              temp: numeratorTemp / denominator,
              precip: numeratorPrecip / denominator,
              feelslike: 0, precipprob: 0, uvindex: 0, visibility: 0, windspeed: 0
          ));
        }
      }
    }
    return result;
  }

  Future<void> _loadGeoJsonBoundary() async {
    try {
      String geoJsonString = await rootBundle.loadString('assets/hcm_boundary.geojson');
      final data = jsonDecode(geoJsonString);
      List<dynamic> features = data['features'];

      _hcmBoundaryPoints.clear();
      Set<Polygon> polygons = {};

      for (var feature in features) {
        String type = feature['geometry']['type'];
        List<dynamic> coordinates = feature['geometry']['coordinates'];

        if (type == 'Polygon') {
          _processPolygonCoords(coordinates[0], polygons);
        } else if (type == 'MultiPolygon') {
          for (var polyCoords in coordinates) {
            _processPolygonCoords(polyCoords[0], polygons);
          }
        }
      }
      _boundaryPolygons = polygons;
      print("✅ Đã load ranh giới TP.HCM");
    } catch (e) {
      print("❌ Lỗi load GeoJSON: $e");
    }
  }

  void _processPolygonCoords(List<dynamic> coords, Set<Polygon> polygons) {
    List<mp.LatLng> mpPoints = [];
    List<LatLng> googlePoints = [];

    for (var point in coords) {
      double lon = (point[0] as num).toDouble();
      double lat = (point[1] as num).toDouble();
      mpPoints.add(mp.LatLng(lat, lon));
      googlePoints.add(LatLng(lat, lon));
    }
    _hcmBoundaryPoints.add(mpPoints);

    polygons.add(Polygon(
      polygonId: PolygonId('boundary_${polygons.length}'),
      points: googlePoints,
      strokeColor: Colors.black54,
      strokeWidth: 2,
      fillColor: Colors.transparent,
      zIndex: 2,
    ));
  }

  Future<void> findRoute(String origin, String dest, String travelMode, BuildContext context, {int? favoriteRouteId}) async {
    if (origin.isEmpty || dest.isEmpty) {
      _errorMessage = "Vui lòng nhập điểm đi và điểm đến!";
      notifyListeners();
      return;
    }
    _isLoading = true;
    clearMapData();
    notifyListeners();

    try {
      String originQuery = origin;
      if (origin.toLowerCase() == "vị trí của bạn") {
        Position currentPos = await _determinePosition();
        originQuery = "${currentPos.latitude},${currentPos.longitude}";
      }

      final directions = await _googleMapsService.getDirections(originQuery, dest, travelMode);

      if (directions.containsKey('warning_message')) {
        final snackBar = SnackBar(content: Text(directions['warning_message']), backgroundColor: Colors.orange[700]);
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }

      if (directions['routes'] == null || (directions['routes'] as List).isEmpty) {
        throw Exception("Không tìm thấy tuyến đường.");
      }

      List<Map<String, dynamic>> routesFromApi = List<Map<String, dynamic>>.from(directions['routes']);
      List<Future<Map<String, dynamic>>> weatherFetchFutures = [];

      for (var route in routesFromApi) {
        weatherFetchFutures.add(_fetchAndAttachWeatherForRoute(route));
      }

      _routes = await Future.wait(weatherFetchFutures);
      _calculateAndSetRecommendedRoute();
      _selectedRouteIndex = _recommendedRouteIndex >= 0 ? _recommendedRouteIndex : 0;

      await _updateUIAfterFindingRoutes(context);

    } catch (e) {
      _errorMessage = "Lỗi: ${e.toString()}";
      print(_errorMessage);
    } finally {
      _isLoading = false;
      _showLegend = true;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _fetchAndAttachWeatherForRoute(Map<String, dynamic> route) async {
    try {
      final leg = route['legs'][0];
      final startLocation = LatLng(leg['start_location']['lat'], leg['start_location']['lng']);
      final endLocation = LatLng(leg['end_location']['lat'], leg['end_location']['lng']);

      final polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(route['overview_polyline']['points']);
      List<LatLng> polylineCoordinates = result.map((p) => LatLng(p.latitude, p.longitude)).toList();

      final List<String> waypointsWithTime = [];
      final int totalDurationInSeconds = leg['duration']['value'];
      final double totalDistance = (leg['distance']['value'] as num).toDouble();

      if (polylineCoordinates.length > 1 && totalDurationInSeconds > 0) {
        final double averageSpeed = totalDistance / totalDurationInSeconds;
        const double samplingDistance = 2000.0;
        double cumulativeDistance = 0.0;
        double distanceForInterval = 0.0;

        for (int i = 0; i < polylineCoordinates.length - 1; i++) {
          final LatLng startSegment = polylineCoordinates[i];
          final LatLng endSegment = polylineCoordinates[i + 1];
          final double segmentDistance = Geolocator.distanceBetween(
              startSegment.latitude, startSegment.longitude, endSegment.latitude, endSegment.longitude);

          distanceForInterval += segmentDistance;

          while (distanceForInterval >= samplingDistance) {
            final double overshoot = distanceForInterval - samplingDistance;
            final double interpolationRatio = (segmentDistance - overshoot) / segmentDistance;

            final LatLng waypointPosition = LatLng(
              startSegment.latitude + (endSegment.latitude - startSegment.latitude) * interpolationRatio,
              startSegment.longitude + (endSegment.longitude - startSegment.longitude) * interpolationRatio,
            );

            final double cumulativeDistanceToWaypoint = cumulativeDistance + (segmentDistance - overshoot);
            final int timeToWaypointInSeconds = (cumulativeDistanceToWaypoint / averageSpeed).round();
            final DateTime arrivalTime = DateTime.now().add(Duration(seconds: timeToWaypointInSeconds));
            final String formattedTime = DateFormat('HH:mm:ss').format(arrivalTime);

            waypointsWithTime.add("${waypointPosition.latitude},${waypointPosition.longitude};$formattedTime");
            distanceForInterval = overshoot;
          }
          cumulativeDistance += segmentDistance;
        }
      }

      final String destinationWithTime = "${endLocation.latitude},${endLocation.longitude};${DateFormat('HH:mm:ss').format(DateTime.now().add(Duration(seconds: totalDurationInSeconds)))}";

      final requestBody = {
        "origin": "${startLocation.latitude},${startLocation.longitude}",
        "destination": destinationWithTime,
        "waypoints": waypointsWithTime,
        "originAddress": leg['start_address'],
        "originLatitude": startLocation.latitude,
        "originLongitude": startLocation.longitude,
        "destinationAddress": leg['end_address'],
        "destinationLatitude": endLocation.latitude,
        "destinationLongitude": endLocation.longitude,
      };

      final alerts = await _apiService.getWeatherAlerts(requestBody);
      route['weather_alerts'] = alerts.map((alert) => alert.toJson()).toList();

    } catch (e) {
      print("Lỗi khi lấy thời tiết cho 1 tuyến đường: $e");
      route['weather_alerts'] = [];
    }
    return route;
  }

  void _calculateAndSetRecommendedRoute() {
    if (_routes.isEmpty) {
      _recommendedRouteIndex = -1;
      return;
    }

    double bestScore = double.negativeInfinity;
    int bestIndex = 0;

    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      final leg = route['legs'][0];
      final alerts = route['weather_alerts'] as List<dynamic>? ?? [];

      double weatherScore = 0;
      for (var alertJson in alerts) {
        double prob = (alertJson['precipprob'] as num? ?? 0.0).toDouble();
        String icon = alertJson['icon'] ?? '';
        double wind = (alertJson['windspeed'] as num? ?? 0.0).toDouble();

        if (prob >= 80) weatherScore -= 50;
        else if (prob >= 50) weatherScore -= 30;
        else if (prob >= 30) weatherScore -= 10;

        if (icon == 'fog') weatherScore -= 20;
        if (icon == 'high-uv') weatherScore -= 5;
        if (wind > 40) weatherScore -= 15;
      }

      final durationInSeconds = leg['duration']['value'] as int;
      double travelScore = 1000 / (durationInSeconds + 1);
      const double weatherWeight = 100.0;
      const double travelWeight = 1.0;

      double totalScore = (weatherScore * weatherWeight) + (travelScore * travelWeight);

      if (totalScore > bestScore) {
        bestScore = totalScore;
        bestIndex = i;
      }
    }
    _recommendedRouteIndex = bestIndex;
  }

  Future<void> saveCurrentRouteToHistory() async {
    if (_currentRouteContext == null) return;

    try {
      final routeInfo = {
        "originAddress": _currentRouteContext!['startAddr'],
        "originLatitude": _currentRouteContext!['start'].latitude,
        "originLongitude": _currentRouteContext!['start'].longitude,
        "destinationAddress": _currentRouteContext!['endAddr'],
        "destinationLatitude": _currentRouteContext!['end'].latitude,
        "destinationLongitude": _currentRouteContext!['end'].longitude,
      };

      final alerts = _weatherAlerts.map((e) => e.toJson()).toList();

      await _apiService.saveRouteLog(routeInfo, alerts);
      print("✅ Đã lưu lịch sử chuyến đi.");
    } catch (e) {
      print("❌ Lỗi lưu lịch sử: $e");
    }
  }

  Future<void> fetchWeatherForSelectedRoute(BuildContext context) async {
    if (!hasRoutes) return;
    _isLoading = true;
    notifyListeners();

    try {
      final selectedRoute = _routes[_selectedRouteIndex];
      final alerts = (selectedRoute['weather_alerts'] as List<dynamic>?)
          ?.map((a) => WeatherAlert.fromJson(a as Map<String, dynamic>))
          .toList() ?? [];

      final leg = selectedRoute['legs'][0];
      final startLocation = LatLng(leg['start_location']['lat'], leg['start_location']['lng']);
      final endLocation = LatLng(leg['end_location']['lat'], leg['end_location']['lng']);

      final polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(selectedRoute['overview_polyline']['points']);
      List<LatLng> polylineCoordinates = result.map((p) => LatLng(p.latitude, p.longitude)).toList();

      _currentRouteContext = {
        'pCoords': polylineCoordinates,
        'start': startLocation,
        'end': endLocation,
        'startAddr': leg['start_address'],
        'endAddr': leg['end_address'],
        'bounds': selectedRoute['bounds'],
        'context': context,
      };

      updateMapUI(polylineCoordinates, startLocation, endLocation, leg['start_address'], leg['end_address'], alerts, selectedRoute['bounds'], context, isRefreshing: true);
      _isRouteConfirmed = true;
      _generateAndAnnounceWeatherSummary(alerts);
      _scheduleNextWeatherRefresh();

    } catch (e) {
      _errorMessage = "Lỗi lấy thời tiết: ${e.toString()}";
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectRoute(int index) {
    if (index != _selectedRouteIndex) {
      _selectedRouteIndex = index;
      _updatePolylinesAppearance();
      notifyListeners();
    }
  }

  void _updatePolylinesAppearance() {
    final updatedPolylines = <Polyline>{};
    for (final polyline in _polylines) {
      final int index = int.parse(polyline.polylineId.value.split('_').last);
      updatedPolylines.add(
        polyline.copyWith(
          colorParam: index == _selectedRouteIndex ? Colors.blue : Colors.grey.withOpacity(0.7),
        ),
      );
    }
    _polylines = updatedPolylines;
  }

  Future<void> _updateUIAfterFindingRoutes(BuildContext context) async {
    if (_routes.isEmpty) return;
    _polylines.clear();
    _markers.clear();
    _weatherAlerts.clear();
    _showLegend = false;

    final PolylinePoints polylinePoints = PolylinePoints();
    for (int i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      final List<PointLatLng> result = polylinePoints.decodePolyline(route['overview_polyline']['points']);
      final List<LatLng> polylineCoordinates = result.map((p) => LatLng(p.latitude, p.longitude)).toList();

      _polylines.add(Polyline(
        polylineId: PolylineId('route_$i'),
        points: polylineCoordinates,
        color: i == _selectedRouteIndex ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.7),
        width: 6,
        consumeTapEvents: true,
        onTap: () {
          selectRoute(i);
        },
      ));
    }

    final selectedRouteLeg = _routes[_selectedRouteIndex]['legs'][0];
    final startLocation = LatLng(selectedRouteLeg['start_location']['lat'], selectedRouteLeg['start_location']['lng']);
    final endLocation = LatLng(selectedRouteLeg['end_location']['lat'], selectedRouteLeg['end_location']['lng']);

    _markers.add(Marker(markerId: const MarkerId('origin'), position: startLocation, infoWindow: InfoWindow(title: 'Điểm đi', snippet: selectedRouteLeg['start_address'])));
    _markers.add(Marker(markerId: const MarkerId('destination'), position: endLocation, infoWindow: InfoWindow(title: 'Điểm đến', snippet: selectedRouteLeg['end_address'])));

    final bounds = _routes[0]['bounds'];
    mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(bounds['southwest']['lat'], bounds['southwest']['lng']),
        northeast: LatLng(bounds['northeast']['lat'], bounds['northeast']['lng']),
      ),
      50.0,
    ));
    notifyListeners();
  }

  void updateMapUI(List<LatLng> pCoords, LatLng start, LatLng end, String startAddr, String endAddr, List<WeatherAlert> alerts, Map<String, dynamic> bounds, BuildContext context, {bool isRefreshing = false}) {
    _markers.removeWhere((m) => m.markerId.value.startsWith("alert_"));
    _circles.clear();

    if (!isRefreshing) {
      _polylines.clear();
      _markers.clear();
      _polylines.add(Polyline(polylineId: const PolylineId('route'), color: Theme.of(context).primaryColor, width: 6, points: pCoords));
      _markers.add(Marker(markerId: const MarkerId('origin'), position: start, infoWindow: InfoWindow(title: 'Điểm đi', snippet: startAddr)));
      _markers.add(Marker(markerId: const MarkerId('destination'), position: end, infoWindow: InfoWindow(title: 'Điểm đến', snippet: endAddr)));
    }

    _weatherAlerts = alerts;
    for (var alert in alerts) {
      try {
        final parts = alert.location.split(',');
        if (parts.length < 2) continue;
        final position = LatLng(double.parse(parts[0]), double.parse(parts[1]));

        const colorGood = Color(0xFF43A047);
        const colorWarning = Color(0xFFFF9800);
        const colorDanger = Color(0xFFFA0606);
        Color statusColor;
        switch (alert.alertType) {
          case 'rain':
            if (alert.precip > 5.0) {
              statusColor = colorDanger;
            } else {
              statusColor = colorWarning;
            }
            break;

          case 'wind':
            if (alert.windspeed > 40.0) {
              statusColor = colorDanger;
            } else {
              statusColor = colorWarning;
            }
            break;

          case 'fog':
            statusColor = colorWarning;
            break;

          case 'high-uv':
            statusColor = colorDanger;
            break;

          case 'clear-day':
          case 'clear-night':
          case 'cloudy':
          case 'partly-cloudy-day':
          case 'partly-cloudy-night':
            statusColor = colorGood;
            break;

          default:
            statusColor = colorGood;
        }
        _circles.add(Circle(
          circleId: CircleId(alert.location),
          center: position,
          radius: 1000.0,

          fillColor: statusColor.withOpacity(0.25),

          strokeColor: statusColor.withOpacity(0.7),

          strokeWidth: 1,
        ));

        _markers.add(Marker(
          markerId: MarkerId("alert_${alert.location}"),
          position: position,
          icon: _customIcons[alert.alertType] ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          onTap: () => customInfoWindowController.addInfoWindow?.call(
            buildCustomInfoWindowContent(alert, context),
            position,
          ),
        ));
      } catch (e) {
        print("Lỗi khi xử lý alert: $e");
      }
    }

    if (!isRefreshing) {
      _destinationForNav = end;
      mapController?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(bounds['southwest']['lat'], bounds['southwest']['lng']),
          northeast: LatLng(bounds['northeast']['lat'], bounds['northeast']['lng']),
        ),
        50.0,
      ));
    }
    notifyListeners();
  }


  Widget buildCustomInfoWindowContent(WeatherAlert alert, BuildContext context) {
    Map<String, dynamic> getRainInfo() {
      if (alert.precipprob <= 0) {
        return {'text': 'Không mưa', 'icon': Icons.cloud_outlined};
      }
      final roundedProb = (alert.precipprob / 5).floor() * 5;
      String rainLevel;
      if (alert.precip < 2.5) {
        rainLevel = 'Mưa nhỏ';
      } else if (alert.precip <= 7.6) {
        rainLevel = 'Mưa vừa';
      } else {
        rainLevel = 'Mưa to';
      }
      return {'text': '$rainLevel ($roundedProb%)', 'icon': Icons.water_drop};
    }

    final rainInfo = getRainInfo();


    String displayTime = alert.eventTime;
    if (displayTime.split(':').length >= 2) {
      List<String> parts = displayTime.split(':');
      displayTime = "${parts[0]}:${parts[1]}";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 7, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "Dự kiến đến lúc: $displayTime",
              style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 4),
          Text(
              alert.message,
              style: TextStyle(fontWeight: FontWeight.bold, color: alert.getAlertColor(context), fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis
          ),
          const Divider(height: 1, thickness: 0.5),
          _buildInfoRow(context, Icons.thermostat, 'Nhiệt độ: ${alert.temp.toStringAsFixed(1)}°C (Cảm giác: ${alert.feelslike.toStringAsFixed(1)}°C)'),
          _buildInfoRow(context, rainInfo['icon'], rainInfo['text']),
          _buildInfoRow(context, Icons.air, 'Gió: ${alert.windspeed.toStringAsFixed(1)} km/h'),
          // Hiển thị UV nếu có
          if (alert.uvindex > 0)
            _buildInfoRow(context, Icons.wb_sunny, 'Chỉ số UV: ${alert.uvindex.toStringAsFixed(1)}'),
          _buildInfoRow(context, Icons.visibility, 'Tầm nhìn: ${alert.visibility.toStringAsFixed(1)} km'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Future<void> loadCustomIcons() async {
    const iconList = ['rain', 'fog', 'wind', 'cloudy', 'partly-cloudy-day', 'partly-cloudy-night', 'clear-day', 'clear-night', 'unknown', 'high-uv'];
    for (var iconName in iconList) {
      try {
        final String path = 'assets/icons/$iconName.png';
        final icon = await getBitmapDescriptorFromAsset(path, 120);
        _customIcons[iconName] = icon;
      } catch (e) {
        print("Lỗi tải icon: $iconName - $e");
      }
    }
  }

  Future<void> autoSetOriginOnce(TextEditingController controller) async {
    if (_originAutoSetDone) return;
    try {
      Position position = await _determinePosition();
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15));
      controller.text = "Vị trí của bạn";
      _originAutoSetDone = true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchDestinationSuggestions(String input) async {
    if (input.isEmpty) {
      _destSuggestions = [];
      notifyListeners();
      return;
    }
    const apiKey = "key";
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&language=vi&components=country:vn';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List predictions = data['predictions'];
        _destSuggestions = predictions.map((p) => p['description'] as String).toList();
      } else {
        _destSuggestions = [];
      }
    } catch (_) {
      _destSuggestions = [];
    }
    notifyListeners();
  }

  void clearSuggestions() {
    _destSuggestions = [];
    notifyListeners();
  }
  void reset() {
    _routes = [];
    _selectedRouteIndex = 0;
    _recommendedRouteIndex = -1;
    _isRouteConfirmed = false;
    _isLoading = false;
    _errorMessage = '';
    _showLegend = false;
    _isInitialized = false;
    _markers.clear();
    _polylines.clear();
    _circles.clear();
    _overlayGridCircles.clear();
    _boundaryPolygons.clear();
    _weatherAlerts = [];
    _destSuggestions = [];
    _originAutoSetDone = false;
    _savedLocations = [];
    _searchHistory = [];
    _destinationForNav = null;
    _isNavigating = false;
    _weatherRefreshTimer?.cancel();
    _weatherRefreshTimer = null;
    _currentRouteContext = null;
    _favoriteRoutes = [];
    _trafficEnabled = false;
    _isCityOverlayVisible = false;

    mapController = null;

    notifyListeners();
  }

  void clearMapData() {
    _isRouteConfirmed = false;
    _routes.clear();
    _polylines.clear();
    _markers.clear();
    _circles.clear();
    _weatherAlerts.clear();
    _destinationForNav = null;
    _isNavigating = false;
    _errorMessage = '';
    _showLegend = false;
    customInfoWindowController.hideInfoWindow?.call();
    _weatherRefreshTimer?.cancel();
    _currentRouteContext = null;
    notifyListeners();
  }

  void _scheduleNextWeatherRefresh() {
    _weatherRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final durationToWait = nextHour.difference(now);
    _weatherRefreshTimer = Timer(durationToWait, () {
      _refreshWeatherForCurrentRoute();
    });
  }

  Future<void> _refreshWeatherForCurrentRoute() async {
    if (_currentRouteContext == null) return;

    try {
      final LatLng startLocation = _currentRouteContext!['start'];
      final LatLng endLocation = _currentRouteContext!['end'];
      final List<LatLng> polylineCoordinates = _currentRouteContext!['pCoords'];
      final String startAddr = _currentRouteContext!['startAddr'];
      final String endAddr = _currentRouteContext!['endAddr'];
      final Map<String, dynamic> bounds = _currentRouteContext!['bounds'];
      final BuildContext context = _currentRouteContext!['context'];

      final List<String> waypointsWithTime = [];
      const double averageSpeed = 11.0;
      const double samplingDistance = 2000.0;

      double cumulativeDistance = 0.0;
      double distanceForInterval = 0.0;

      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        final LatLng p1 = polylineCoordinates[i];
        final LatLng p2 = polylineCoordinates[i + 1];
        final double segmentDist = Geolocator.distanceBetween(
            p1.latitude, p1.longitude, p2.latitude, p2.longitude);

        distanceForInterval += segmentDist;

        while (distanceForInterval >= samplingDistance) {
          final double overshoot = distanceForInterval - samplingDistance;
          final double ratio = (segmentDist - overshoot) / segmentDist;

          final LatLng wp = LatLng(
            p1.latitude + (p2.latitude - p1.latitude) * ratio,
            p1.longitude + (p2.longitude - p1.longitude) * ratio,
          );

          final double distFromStart = cumulativeDistance + (segmentDist - overshoot);
          final int secondsFromNow = (distFromStart / averageSpeed).round();

          final DateTime arrivalTime = DateTime.now().add(Duration(seconds: secondsFromNow));
          final String formattedTime = DateFormat('HH:mm:ss').format(arrivalTime);

          waypointsWithTime.add("${wp.latitude},${wp.longitude};$formattedTime");
          distanceForInterval = overshoot;
        }
        cumulativeDistance += segmentDist;
      }

      final String destinationWithTime =
          "${endLocation.latitude},${endLocation.longitude};${DateFormat('HH:mm:ss').format(DateTime.now().add(Duration(seconds: (cumulativeDistance/averageSpeed).round())))}";

      final requestBody = {
        "origin": "${startLocation.latitude},${startLocation.longitude}",
        "destination": destinationWithTime,
        "waypoints": waypointsWithTime,
        "originAddress": startAddr,
        "originLatitude": startLocation.latitude,
        "originLongitude": startLocation.longitude,
        "destinationAddress": endAddr,
        "destinationLatitude": endLocation.latitude,
        "destinationLongitude": endLocation.longitude,
      };

      final List<WeatherAlert> newAlerts = await _apiService.getWeatherAlerts(requestBody);

      updateMapUI(
          polylineCoordinates,
          startLocation,
          endLocation,
          startAddr,
          endAddr,
          newAlerts,
          bounds,
          context,
          isRefreshing: true
      );

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Dữ liệu thời tiết trên lộ trình đã được cập nhật theo giờ mới."),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          )
      );

      if (_isNavigating) {
        _navigationService.stopTracking();
        _navigationService.startTracking(newAlerts, polylineCoordinates);
      }else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Dữ liệu thời tiết đã được cập nhật."),
              duration: Duration(seconds: 2),
            )
        );
      }

      _scheduleNextWeatherRefresh();

    } catch (e) {
      print("Lỗi khi tự động cập nhật thời tiết: $e");
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> launchGoogleMapsNavigation() async {
    if (_currentRouteContext == null) return;

    try {
      final LatLng origin = _currentRouteContext!['start'];
      final LatLng destination = _currentRouteContext!['end'];

      final Map<String, String> queryParameters = {
        'api': '1',
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'travelmode': 'driving',
      };

      final uri = Uri.https('www.google.com', '/maps/dir/', queryParameters);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        startVoiceTracking();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void startVoiceTracking() {
    if (_weatherAlerts.isNotEmpty && _currentRouteContext != null) {
      List<LatLng> routeCoords = _currentRouteContext!['pCoords'];
      _navigationService.startTracking(_weatherAlerts, routeCoords);
      _isNavigating = true;
      saveCurrentRouteToHistory();
      notifyListeners();
    }
  }

  void stopVoiceTracking() {
    _navigationService.stopTracking();
    _isNavigating = false;
    notifyListeners();
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Dịch vụ định vị đã bị tắt.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Quyền truy cập vị trí bị từ chối.');
    }
    if (permission == LocationPermission.deniedForever) return Future.error('Quyền vị trí bị từ chối vĩnh viễn.');
    return await Geolocator.getCurrentPosition();
  }

  Future<void> animateToCurrentLocation() async {
    try {
      Position position = await _determinePosition();
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15));
    } catch (e) {
      _errorMessage = "Lỗi định vị: ${e.toString()}";
      notifyListeners();
    }
  }

  void _generateAndAnnounceWeatherSummary(List<WeatherAlert> alerts) {
    if (alerts.isEmpty) {
      _navigationService.speak("Thời tiết trên lộ trình của bạn được dự báo là khá tốt.");
      return;
    }
    int rainCount = alerts.where((a) => a.alertType.toLowerCase().contains('rain')).length;
    int windCount = alerts.where((a) => a.windspeed >= 39).length;
    int fogCount = alerts.where((a) => a.alertType.toLowerCase() == 'fog').length;

    List<String> summaryParts = [];
    if (rainCount > 0) summaryParts.add("$rainCount điểm có thể có mưa");
    if (windCount > 0) summaryParts.add("$windCount điểm gió mạnh");
    if (fogCount > 0) summaryParts.add("$fogCount điểm có sương mù");

    if (summaryParts.isEmpty) {
      _navigationService.speak("Thời tiết trên lộ trình khá tốt.");
      return;
    }
    String summaryText = "Lưu ý: Lộ trình có ${summaryParts.join(' và ')}. Vui lòng di chuyển cẩn thận.";
    _navigationService.speak(summaryText);
  }

  Future<void> loadFavoriteRoutes() async {
    try {
      _favoriteRoutes = await _apiService.getFavoriteRoutes();
      notifyListeners();
    } catch (e) {
      print(e);
    }
  }

  Future<void> addFavoriteRoute(Map<String, dynamic> routeData) async {
    try {
      await _apiService.createFavoriteRoute(routeData);
      await loadFavoriteRoutes();
    } catch (e) {
      print(e);
    }
  }

  Future<void> deleteFavoriteRoute(int routeId) async {
    try {
      await _apiService.deleteFavoriteRoute(routeId);
      _favoriteRoutes.removeWhere((route) => route['id'] == routeId);
      notifyListeners();
    } catch (e) {
      print(e);
    }
  }

  Future<void> loadHistoryAndSavedLocations() async {
    try {
      try {
        _savedLocations = await _apiService.getSavedLocations();
      } catch (e) {
        print("Lỗi tải địa điểm đã lưu: $e");
        _savedLocations = [];
      }

      try {
        _searchHistory = await _apiService.getSearchHistory();
      } catch (e) {
        print("Lỗi tải lịch sử tìm kiếm: $e");
        _searchHistory = [];
      }

    } catch (e) {
      print("Lỗi chung loadHistoryAndSavedLocations: $e");
    } finally {
      notifyListeners();
    }
  }

  Future<void> addSearchToHistory(String query) async {
    if (query.isEmpty || query.toLowerCase() == "vị trí của bạn") return;
    try {
      await _apiService.addSearchHistory(query);
      _searchHistory = await _apiService.getSearchHistory();
      notifyListeners();
    } catch (e) {
      print(e);
    }
  }
}