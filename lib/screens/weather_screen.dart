import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';
import '../models/weather_alert.dart';
import 'login_screen.dart';
import 'package:fl_chart/fl_chart.dart';
class WeatherData {
  final WeatherAlert currentWeather;
  final List<WeatherAlert> hourlyForecast;
  final String locationName;


  WeatherData({
    required this.currentWeather,
    required this.hourlyForecast,
    required this.locationName,
  });
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late Future<WeatherData> _weatherFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchCurrentWeatherAndLocationName();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  TextStyle getShadowTextStyle(BuildContext context, {double fontSize = 14, FontWeight fontWeight = FontWeight.normal}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: Colors.white, // Luôn là màu trắng để nổi trên nền tối/ảnh
      shadows: [
        Shadow(
          offset: const Offset(0, 1),
          blurRadius: 3.0,
          color: Colors.black.withOpacity(0.6), // Đổ bóng đen giúp chữ nổi lên
        ),
      ],
    );
  }

  Future<WeatherData> _fetchCurrentWeatherAndLocationName() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Dịch vụ định vị (GPS) của bạn đang tắt.');
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      final results = await Future.wait([
        _apiService.getCurrentWeather(position.latitude, position.longitude),
        _apiService.getHourlyForecast(position.latitude, position.longitude),
      ]);

      final weatherData = results[0] as WeatherAlert;
      final forecastData = results[1] as List<WeatherAlert>;
      String locationNameToDisplay;

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 5));

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String mainLocation = place.subAdministrativeArea ?? place.locality ?? '';
          String region = place.administrativeArea ?? '';
          locationNameToDisplay = [mainLocation, region].where((s) => s.isNotEmpty).join(', ');
        } else {
          locationNameToDisplay = "Vị trí hiện tại";
        }
      } on TimeoutException {
        print("Lỗi Geocoding: Quá thời gian chờ (Timeout).");
        locationNameToDisplay = "Vị trí hiện tại (Không thể lấy tên)";
      } catch (e) {
        print("Lỗi Geocoding: $e");
        locationNameToDisplay = "Vị trí hiện tại";
      }

      return WeatherData(
        currentWeather: weatherData,
        hourlyForecast: forecastData,
        locationName: locationNameToDisplay,
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  void _refreshWeather() {
    setState(() {
      _weatherFuture = _fetchCurrentWeatherAndLocationName();
    });
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final gradient = isLightTheme
        ? const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF2563EB),
        Color(0xFF60A5FA),
      ],
    )
        : null;

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Scaffold(
        backgroundColor: isLightTheme ? Colors.transparent : null,
        body: SafeArea(
          child: FutureBuilder<WeatherData>(
            future: _weatherFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError) {
                return _buildErrorWidget(snapshot.error.toString());
              }
              if (snapshot.hasData) {
                return _buildWeatherInfo(snapshot.data!);
              }
              return _buildErrorWidget("Không có dữ liệu để hiển thị.");
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherInfo(WeatherData data) {
    final weather = data.currentWeather;
    final locationName = data.locationName;
    final hourlyForecast = data.hourlyForecast;

    return RefreshIndicator(
      onRefresh: () async => _refreshWeather(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        children: [
          const SizedBox(height: 20),

          Text(
            locationName,
            textAlign: TextAlign.center,
            style: getShadowTextStyle(context, fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                "${weather.temp.round()}°",
                textAlign: TextAlign.center,
                style: getShadowTextStyle(context, fontSize: 100, fontWeight: FontWeight.w200),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getWeatherIcon(weather.alertType), color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(weather.message, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Cảm giác như: ${weather.feelslike.round()}°",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 30),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white.withOpacity(0.1),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  tabs: const [
                    Tab(text: 'Nhiệt độ'),
                    Tab(text: 'Khả năng mưa'),
                  ],
                ),
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildTemperatureChart(hourlyForecast),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildPrecipitationChart(hourlyForecast),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildDetailsCard(weather),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart(List<WeatherAlert> hourlyForecast) {
    final forecastToShow = hourlyForecast;
    if (forecastToShow.isEmpty) {
      return const Center(child: Text("Không có dữ liệu dự báo.", style: TextStyle(color: Colors.white70)));
    }

    double minTemp = forecastToShow.first.temp;
    double maxTemp = forecastToShow.first.temp;
    for (var alert in forecastToShow) {
      if (alert.temp < minTemp) minTemp = alert.temp;
      if (alert.temp > maxTemp) maxTemp = alert.temp;
    }

    const double verticalPadding = 5.0;
    final double chartMinY = (minTemp - verticalPadding).floorToDouble();
    final double chartMaxY = (maxTemp + verticalPadding).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: chartMinY,
        maxY: chartMaxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.round()}°C',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(show: true,
          drawVerticalLine: false,),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),

          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= forecastToShow.length) return const SizedBox();
                final temp = forecastToShow[value.toInt()].temp;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '${temp.round()}°',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                );
              },
            ),
          ),

          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= forecastToShow.length) return const SizedBox();
                final hour = forecastToShow[value.toInt()].eventTime.substring(0, 5);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(hour, style: const TextStyle(color: Colors.white, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: forecastToShow.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.temp);
            }).toList(),
            isCurved: true,
            gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [Colors.amber.withOpacity(0.3), Colors.orange.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrecipitationChart(List<WeatherAlert> hourlyForecast) {
    final forecastToShow = hourlyForecast;
    if (forecastToShow.isEmpty) {
      return const Center(child: Text("Không có dữ liệu dự báo.", style: TextStyle(color: Colors.white70)));
    }

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.round()}%',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        gridData: FlGridData(show: true,
          drawVerticalLine: false,),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),

          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= forecastToShow.length) return const SizedBox();
                final prob = forecastToShow[value.toInt()].precipprob;
                if (prob <= 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '${prob.round()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                );
              },
            ),
          ),

          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= forecastToShow.length) return const SizedBox();
                final hour = forecastToShow[value.toInt()].eventTime.substring(0, 5);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(hour, style: const TextStyle(color: Colors.white, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: 105,
        barGroups: forecastToShow.asMap().entries.map((entry) {
          final prob = entry.value.precipprob;
          Color barColor = prob > 50 ? Colors.blueAccent : Colors.blue.withOpacity(0.5);

          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: prob,
                color: barColor,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    bool isAuthError = error.contains('hết hạn');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.yellow[700], size: 60),
            const SizedBox(height: 20),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isAuthError ? _logout : _refreshWeather,
              icon: Icon(isAuthError ? Icons.logout : Icons.refresh),
              label: Text(isAuthError ? 'Đăng nhập lại' : 'Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isAuthError ? Colors.redAccent : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(WeatherAlert weather) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _detailItem(Icons.air, "${weather.windspeed.round()} km/h", "Gió"),
              _detailItem(Icons.water_drop_outlined, "${weather.precipprob.round()}%", "Khả năng mưa"),
              _detailItem(Icons.wb_sunny_outlined, "${weather.uvindex.round()}", "Chỉ số UV"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  IconData _getWeatherIcon(String alertType) {
    switch (alertType.toLowerCase()) {
      case 'rain': return Icons.water_drop;
      case 'clear-day': return Icons.wb_sunny;
      case 'clear-night': return Icons.nightlight_round;
      case 'cloudy': return Icons.cloud;
      case 'partly-cloudy-day': return Icons.cloud_outlined;
      case 'partly-cloudy-night': return Icons.nights_stay;
      case 'wind': return Icons.air;
      case 'fog': return Icons.foggy;
      case 'high-uv': return Icons.brightness_high;
      default: return Icons.wb_cloudy;
    }
  }
}