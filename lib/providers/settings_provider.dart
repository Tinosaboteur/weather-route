import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  MapType _mapType = MapType.normal;
  String _travelMode = 'driving';
  bool _isLoading = true;

  MapType get mapType => _mapType;
  String get travelMode => _travelMode;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _apiService.getUserSettings();
      _mapType = _stringToMapType(settings['mapType'] ?? 'normal');
      _travelMode = settings['travelMode'] ?? 'driving';
    }catch (e) {
      print("Failed to load settings: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateSettingsOnServer() async {
    await _apiService.updateUserSettings({
      'mapType': _mapTypeToString(_mapType),
      'travelMode': _travelMode,
    });
  }

  Future<void> updateTravelMode(String newMode) async {
    if (_travelMode == newMode) return;
    _travelMode = newMode;
    notifyListeners();
    await _updateSettingsOnServer();
  }

  Future<void> updateMapType(MapType newMapType) async {
    if (_mapType == newMapType) return;
    _mapType = newMapType;
    notifyListeners();
    await _updateSettingsOnServer();
  }

  MapType _stringToMapType(String mapTypeString) {
    switch (mapTypeString) {
      case 'satellite':
        return MapType.satellite;
      case 'hybrid':
        return MapType.hybrid;
      case 'terrain':
        return MapType.terrain;
      default:
        return MapType.normal;
    }
  }

  String _mapTypeToString(MapType mapType) {
    return mapType.toString().split('.').last;
  }
  void reset() {
    _mapType = MapType.normal;
    _travelMode = 'driving';
    _isLoading = true;
    notifyListeners();
  }
}