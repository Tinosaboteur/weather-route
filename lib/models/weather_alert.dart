import 'package:flutter/material.dart';

class WeatherAlert {
  final String location;
  final String message;
  final String alertType;
  final String icon;
  final String eventTime;

  final double temp;
  final double feelslike;
  final double precipprob;
  final double precip;
  final double uvindex;
  final double visibility;
  final double windspeed;

  WeatherAlert({
    required this.location,
    required this.message,
    required this.alertType,
    required this.icon,
    required this.eventTime,
    required this.temp,
    required this.feelslike,
    required this.precipprob,
    required this.precip,
    required this.uvindex,
    required this.visibility,
    required this.windspeed,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      location: json['location'] ?? 'N/A',
      message: json['message'] ?? 'Không rõ',
      alertType: json['alertType'] ?? 'unknown',
      icon: json['icon'] ?? 'unknown',
      eventTime: json['datetime'] ?? json['eventTime'] ?? '--:--',

      temp: (json['temp'] as num? ?? 0.0).toDouble(),
      feelslike: (json['feelslike'] as num? ?? 0.0).toDouble(),
      precipprob: (json['precipprob'] as num? ?? 0.0).toDouble(),
      precip: (json['precip'] as num? ?? 0.0).toDouble(),
      uvindex: (json['uvindex'] as num? ?? 0.0).toDouble(),
      visibility: (json['visibility'] as num? ?? 0.0).toDouble(),
      windspeed: (json['windspeed'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'message': message,
      'alertType': alertType,
      'icon': icon,
      'eventTime': eventTime,
      'temp': temp,
      'feelslike': feelslike,
      'precipprob': precipprob,
      'precip': precip,
      'uvindex': uvindex,
      'visibility': visibility,
      'windspeed': windspeed,
    };
  }

  Color getAlertColor(BuildContext context) {
    switch (icon) {
      case 'rain':
      case 'high-uv':
        return const Color(0xFFFA0606);
      case 'fog':
      case 'wind':
        return const Color(0xFFFF9800);
      case 'cloudy':
      case 'partly-cloudy-day':
      case 'partly-cloudy-night':
        return Colors.blueGrey;
      case 'clear-day':
      case 'clear-night':
        return const Color(0xFF43A047);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String get iconPath {
    return 'assets/icons/$icon.png';
  }
}