import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:just_audio/just_audio.dart';
import '../models/weather_alert.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mp;

class AlertPoint {
  final WeatherAlert alert;
  final LatLng position;
  DateTime? lastSpoken;
  AlertPoint(this.alert)
      : position = LatLng(
    double.parse(alert.location.split(',')[0]),
    double.parse(alert.location.split(',')[1]),
  );
}

class NavigationService {
  List<mp.LatLng> _currentRoutePath = [];
  int _alertCount = 0;
  DateTime? _lastAlertWarningTime;
  static const double DEVIATION_TOLERANCE = 0.0005;
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();
  Position? _lastKnownPosition;

  final FlutterTts _flutterTts = FlutterTts();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<Position>? _positionStream;
  List<AlertPoint> _trackingAlerts = [];

  static const int PROXIMITY_THRESHOLD = 5000;
  static const int REPEAT_WARNING_INTERVAL = 90;

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(settings);
    await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    await _setupTts();

    try {
      await _audioPlayer.setAsset('assets/audio/ping.mp3');
    } catch (e) {
      debugPrint("Lỗi tải file âm thanh 'ping.mp3': $e. Âm thanh báo hiệu sẽ bị tắt.");
    }
  }

  Future<void> speak(String text, {bool playSound = false}) async {
    if (playSound && _audioPlayer.processingState != ProcessingState.loading) {
      try {
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (e) {
        debugPrint("Không thể phát âm thanh báo hiệu: $e");
      }
    }
    await _flutterTts.speak(text);
  }

  void startTracking(List<WeatherAlert> allAlerts, List<LatLng> routePolyline) {
    _currentRoutePath = routePolyline
        .map((e) => mp.LatLng(e.latitude, e.longitude))
        .toList();

    _alertCount = 0;
    _lastAlertWarningTime = null;

    _updateTrackingList(allAlerts);

    if (_trackingAlerts.isEmpty) {
      debugPrint("Không có cảnh báo nguy hiểm nào để theo dõi.");
      speak("Lộ trình thông thoáng. Chúc bạn có một chuyến đi an toàn.");
      return;
    }

    _announceRouteSummary();

    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _lastKnownPosition = position;
      _checkProximityToAlerts(position);
      _checkRouteAlert(position);
    });
  }
  void _checkRouteAlert(Position position) {
    if (_currentRoutePath.isEmpty) return;

    final currentPoint = mp.LatLng(position.latitude, position.longitude);

    bool isOnPath = mp.PolygonUtil.isLocationOnPath(
        currentPoint,
        _currentRoutePath,
        false,
        tolerance: DEVIATION_TOLERANCE
    );

    if (!isOnPath) {
      final now = DateTime.now();

      if (_lastAlertWarningTime == null ||
          now.difference(_lastAlertWarningTime!).inSeconds >= 10) {

        _alertCount++;
        _lastAlertWarningTime = now;

        if (_alertCount <= 6) {
          String warningMsg = "Cảnh báo đang đi không đúng lộ trình, ứng dụng có thể sẽ hoạt động không đúng và bị dừng.";

          speak(warningMsg, playSound: true);

          _showNotification("deviation", warningMsg);

          debugPrint("⚠️ LỆCH ĐƯỜNG LẦN $_alertCount: $warningMsg");
        }

        if (_alertCount >= 6) {
          speak("Đã tự động tắt theo dõi do đi sai lộ trình quá nhiều lần.");
          stopTracking();
        }
      }
    } else {
      if (_alertCount > 0) {
        _alertCount = 0;
        debugPrint("✅ Đã quay lại đúng lộ trình.");
      }
    }
  }

  void updateAlerts(List<WeatherAlert> newAlerts) {
    speak("Dữ liệu thời tiết đã được cập nhật theo giờ mới.", playSound: true);

    _updateTrackingList(newAlerts);

    if (_trackingAlerts.isNotEmpty) {
      Future.delayed(const Duration(seconds: 4), () {
        _announceRouteSummary();
      });
    } else {
      speak("Lộ trình hiện tại đã thông thoáng.");
    }

    if (_lastKnownPosition != null) {
      _checkProximityToAlerts(_lastKnownPosition!);
    }
  }
  void _updateTrackingList(List<WeatherAlert> allAlerts) {
    _trackingAlerts = allAlerts
        .where((alert) {
      final type = alert.alertType.toLowerCase();
      return type == 'rain' || type == 'fog' || type == 'wind';
    })
        .map((alert) => AlertPoint(alert))
        .toList();
  }

  void stopTracking() {
    _positionStream?.cancel();
    _flutterTts.stop();
    _trackingAlerts.clear();
    debugPrint("Đã dừng theo dõi vị trí.");
    speak("Đã dừng theo dõi vị trí.");
  }

  void _announceRouteSummary() {
    int rainCount = _trackingAlerts.where((p) => p.alert.alertType.toLowerCase() == 'rain').length;
    int fogCount = _trackingAlerts.where((p) => p.alert.alertType.toLowerCase() == 'fog').length;
    int windCount = _trackingAlerts.where((p) => p.alert.alertType.toLowerCase() == 'wind').length;

    List<String> summaryParts = [];
    if (rainCount > 0) summaryParts.add("$rainCount điểm cảnh báo mưa");
    if (fogCount > 0) summaryParts.add("$fogCount điểm sương mù");
    if (windCount > 0) summaryParts.add("$windCount điểm gió mạnh");

    String summary = "Bắt đầu theo dõi lộ trình. Lưu ý: ${summaryParts.join(' và ')}. Vui lòng di chuyển cẩn thận.";
    debugPrint(summary);
    speak(summary);
  }

  Future<void> _setupTts() async {
    await _flutterTts.awaitSpeakCompletion(true);
    try {
      await _flutterTts.setLanguage("vi-VN");
    } catch (e) {
      debugPrint("Cảnh báo: Không hỗ trợ ngôn ngữ tiếng Việt, sử dụng tiếng Anh.");
      await _flutterTts.setLanguage("en-US");
    }
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  void _checkProximityToAlerts(Position currentPosition) {
    AlertPoint? closestAlertPoint;
    double minDistance = double.infinity;

    for (var alertPoint in _trackingAlerts) {
      double distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude, currentPosition.longitude,
        alertPoint.position.latitude, alertPoint.position.longitude,
      );

      if (distanceInMeters < PROXIMITY_THRESHOLD && distanceInMeters < minDistance) {
        minDistance = distanceInMeters;
        closestAlertPoint = alertPoint;
      }
    }

    if (closestAlertPoint != null) {
      final now = DateTime.now();
      final lastSpoken = closestAlertPoint.lastSpoken;

      if (lastSpoken == null || now.difference(lastSpoken).inSeconds > REPEAT_WARNING_INTERVAL) {
        closestAlertPoint.lastSpoken = now;
        _triggerWarning(closestAlertPoint, minDistance);
      }
    }
  }

  void _triggerWarning(AlertPoint alertPoint, double distance) {
    String alertTypeName;
    switch (alertPoint.alert.alertType.toLowerCase()) {
      case 'rain':
        alertTypeName = 'phía trước có mưa';
        break;
      case 'fog':
        alertTypeName = 'phía trước có sương mù, tầm nhìn kém';
        break;
      case 'wind':
        alertTypeName = 'phía trước có gió mạnh';
        break;
      default:
        alertTypeName = 'cảnh báo thời tiết';
    }

    String distanceText;
    if (distance > 1000) {
      distanceText = "cách khoảng ${(distance / 1000).toStringAsFixed(1)} ki lô mét";
    } else {
      int roundedDistance = (distance / 50).round() * 50;
      distanceText = "cách khoảng $roundedDistance mét";
    }

    String warningMessage = "$alertTypeName, $distanceText.";

    debugPrint("VOICE WARNING: $warningMessage");
    speak(warningMessage, playSound: true);

    _showNotification(alertPoint.alert.alertType, "Cảnh báo: $warningMessage");
  }

  Future<void> _showNotification(String alertType, String message) async {
    String channelId = '${alertType}_alert_channel';
    String channelName = 'Cảnh báo ${alertType.capitalize()}';
    String channelDescription = 'Kênh thông báo cho cảnh báo $alertType';

    final androidDetails = AndroidNotificationDetails(
      channelId, channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Cảnh báo thời tiết!',
      message,
      notificationDetails,
    );
  }
}

  extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}