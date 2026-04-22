import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../models/weather_alert.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';

import '../providers/settings_provider.dart';
import '../providers/map_provider.dart';
import '../utils/palettes.dart';
import 'search_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  late Future<void> _initFuture;
  bool _isSearchPanelVisible = true;

  late final AnimationController _animCtrl;
  bool _isLegendExpanded = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    if (_isSearchPanelVisible) {
      _animCtrl.value = 1.0;
    }
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    _initFuture = mapProvider.initialize().then((_) {
      if (mounted) {
        mapProvider.autoSetOriginOnce(_originController);
        mapProvider.loadFavoriteRoutes();
      }
    });
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _showLoginRequiredDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yêu cầu đăng nhập'),
        content: const Text('Bạn cần đăng nhập để sử dụng tính năng này.'),
        actions: [
          TextButton(
            child: const Text('Đóng'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Đăng nhập'),
            onPressed: () {
              authProvider.logout().then((_) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              });
            },
          )
        ],
      ),
    );
  }

  void _navigateToSearchScreen(BuildContext context, bool isOrigin) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          initialValue: isOrigin ? _originController.text : _destinationController.text,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (isOrigin) {
          _originController.text = result;
        } else {
          _destinationController.text = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi khởi tạo: ${snapshot.error}'));
        }

        return Consumer2<MapProvider, SettingsProvider>(
          builder: (context, mapProvider, settingsProvider, child) {
            return Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Stack(
                children: [
                  GoogleMap(
                    trafficEnabled: mapProvider.trafficEnabled,
                    mapType: settingsProvider.mapType,
                    initialCameraPosition: mapProvider.initialCameraPosition,
                    onMapCreated: (controller) => mapProvider.setMapController(controller),
                    markers: mapProvider.markers,
                    polylines: mapProvider.polylines,
                    circles: mapProvider.circles,
                    polygons: mapProvider.allPolygons,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onTap: (pos) => mapProvider.customInfoWindowController.hideInfoWindow?.call(),
                    onCameraMove: (pos) => mapProvider.customInfoWindowController.onCameraMove?.call(),
                  ),

                  CustomInfoWindow(
                    controller: mapProvider.customInfoWindowController,
                    height: 190,
                    width: 285,
                    offset: 35,
                  ),

                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          _buildAnimatedSearchPanel(context, mapProvider, settingsProvider),
                        ],
                      ),
                    ),
                  ),

                  if (mapProvider.hasRoutes && !mapProvider.isRouteConfirmed)
                    _buildRouteSelectionPanel(mapProvider),

                  if (mapProvider.isRouteConfirmed)
                    _buildNavigationStartPanel(context, mapProvider),

                  Positioned(
                    top: 50,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'legend_toggle',
                          onPressed: () => setState(() => _isLegendExpanded = !_isLegendExpanded),
                          tooltip: _isLegendExpanded ? 'Ẩn chú giải' : 'Hiện chú giải',
                          child: Icon(_isLegendExpanded ? Icons.close : Icons.legend_toggle),
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          elevation: 4,
                        ),
                        const SizedBox(height: 8),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) => SizeTransition(sizeFactor: anim, axisAlignment: 1.0, child: child),
                          child: _isLegendExpanded
                              ? ConstrainedBox(
                            key: const ValueKey('legend_panel'),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                            child: Material(
                              elevation: 10,
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).cardColor.withOpacity(0.98),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: const _ModernLegend(),
                              ),
                            ),
                          )
                              : const SizedBox(key: ValueKey('legend_hidden')),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 230,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'btn_temp_overlay',
                          tooltip: 'Bản đồ Nhiệt độ',
                          backgroundColor: mapProvider.isCityOverlayVisible && mapProvider.overlayType == 'temp'
                              ? Colors.orange
                              : Theme.of(context).cardColor,
                          child: const Icon(Icons.thermostat, color: Colors.red),
                          onPressed: () => mapProvider.toggleCityOverlay('temp'),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'btn_rain_overlay',
                          tooltip: 'Bản đồ Mưa',
                          backgroundColor: mapProvider.isCityOverlayVisible && mapProvider.overlayType == 'rain'
                              ? Colors.blueAccent
                              : Theme.of(context).cardColor,
                          child: const Icon(Icons.water_drop, color: Colors.blue),
                          onPressed: () => mapProvider.toggleCityOverlay('rain'),
                        ),
                      ],
                    ),
                  ),

                  if (mapProvider.isOverlayLoading)
                    Positioned(
                      top: 200,
                      right: 70,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("Đang tải dữ liệu toàn TP...", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),

                  if (mapProvider.isCityOverlayVisible)
                    Positioned(
                      bottom: 40,
                      left: 16,
                      child: _buildOverlayLegend(context, mapProvider.overlayType),
                    ),

                  _buildControlButtons(context, mapProvider),

                  if (mapProvider.isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.45),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOverlayLegend(BuildContext context, String type) {
    List<Color> colors;
    List<String> labels;
    String title;

    if (type == 'temp') {
      title = "Nhiệt độ";
      colors = WeatherPalettes.lstColors;
      labels = ["<24°", "26°", "28°", "30°", "32°", "34°", "36°", ">36°"];
    } else {
      title = "Lượng mưa";
      colors = WeatherPalettes.rainColors.sublist(1);
      labels = ["Nhỏ", "", "Vừa", "", "To"];
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
          const SizedBox(height: 4),
          Row(
            children: List.generate(colors.length, (index) {
              return Container(
                width: 20,
                height: 10,
                color: colors[index],
              );
            }),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(labels.first, style: const TextStyle(fontSize: 10, color: Colors.black)),
              const SizedBox(width: 80),
              Text(labels.last, style: const TextStyle(fontSize: 10, color: Colors.black)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRouteSelectionPanel(MapProvider mapProvider) {
    final PageController pageController = PageController(
      viewportFraction: 0.85,
      initialPage: mapProvider.recommendedRouteIndex >= 0
          ? mapProvider.recommendedRouteIndex
          : 0,
    );

    return Positioned(
      bottom: 15,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 115,
            child: PageView.builder(
              controller: pageController,
              itemCount: mapProvider.routes.length,
              onPageChanged: (index) {
                mapProvider.selectRoute(index);
              },
              itemBuilder: (context, index) {
                final route = mapProvider.routes[index];
                final leg = route['legs'][0];
                final duration = leg['duration']['text'];
                final distance = leg['distance']['text'];
                final isSelected = index == mapProvider.selectedRouteIndex;
                final isRecommended = index == mapProvider.recommendedRouteIndex;
                final weatherAlerts = route['weather_alerts'];

                return GestureDetector(
                  onTap: () => mapProvider.selectRoute(index),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected ? Border.all(color: Colors.white.withOpacity(0.8), width: 2) : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              duration,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            Text(
                              "Khoảng cách: $distance",
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.white70 : Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                            const Divider(height: 10, thickness: 0.5),
                            _buildWeatherSummary(weatherAlerts, isSelected),
                          ],
                        ),
                      ),

                      if (isRecommended)
                        Positioned(
                          top: 10,
                          left: 200,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: const Color(0xFF28a745),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                                ]
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Ưu tiên',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.wb_cloudy_outlined),
            label: const Text("Xem thời tiết cho tuyến này"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
            ),
            onPressed: () {
              mapProvider.fetchWeatherForSelectedRoute(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationStartPanel(BuildContext context, MapProvider mapProvider) {
    final String currentOriginText = _originController.text.trim().toLowerCase();
    final bool canStartTracking = currentOriginText == 'vị trí của bạn';

    if (!canStartTracking) {
      return Positioned(
        bottom: 25,
        left: 0,
        right: 0,
        child: Center(
          child: Text(
            'Chỉ có thể bắt đầu theo dõi từ vị trí hiện tại của bạn.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Positioned(
      bottom: 15,
      left: 0,
      right: 0,
      child: Center(
        child: _buildNavigationFab(context, mapProvider),
      ),
    );
  }

  String _formatTimeDisplay(List<dynamic> alerts, String type) {
    try {
      final filtered = alerts.where((a) =>
          (a['alertType'] as String).toLowerCase().contains(type)).toList();

      if (filtered.isEmpty) return "";

      final firstAlert = filtered.first;
      String rawTime = firstAlert['eventTime'] ?? '';

      List<String> parts = rawTime.split(':');
      if (parts.length >= 2) {
        return " (${parts[0]}:${parts[1]})";
      }
      return "";
    } catch (e) {
      return "";
    }
  }
  Widget _buildWeatherSummary(List<dynamic>? alerts, bool isSelected) {
    final goodWeatherColor = isSelected ? Colors.white : Colors.green;
    final badWeatherColor = isSelected ? Colors.white : Colors.red.shade400;
    final neutralWeatherColor = isSelected ? Colors.white70 : Colors.grey.shade600;

    if (alerts == null || alerts.isEmpty) {
      return Row(
        children: [
          Icon(Icons.check_circle_outline, color: goodWeatherColor, size: 16),
          const SizedBox(width: 6),
          Text("Thời tiết tốt", style: TextStyle(color: neutralWeatherColor, fontSize: 13)),
        ],
      );
    }

    int rainCount = alerts.where((a) => (a['alertType'] as String).toLowerCase().contains('rain')).length;
    int windCount = alerts.where((a) => (a['alertType'] as String).toLowerCase().contains('wind')).length;
    int fogCount = alerts.where((a) => (a['alertType'] as String).toLowerCase().contains('fog')).length;

    if (rainCount > 0) {
      String timeStr = _formatTimeDisplay(alerts, 'rain');
      return Row(
        children: [
          Icon(Icons.water_drop, color: badWeatherColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Có mưa$timeStr",
              style: TextStyle(color: badWeatherColor, fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (windCount > 0) {
      String timeStr = _formatTimeDisplay(alerts, 'wind');
      return Row(
        children: [
          Icon(Icons.air, color: neutralWeatherColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Gió mạnh$timeStr",
              style: TextStyle(color: neutralWeatherColor, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (fogCount > 0) {
      String timeStr = _formatTimeDisplay(alerts, 'fog');
      return Row(
        children: [
          Icon(Icons.visibility_off, color: neutralWeatherColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Sương mù$timeStr",
              style: TextStyle(color: neutralWeatherColor, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.info_outline, color: Colors.amber.shade700, size: 16),
        const SizedBox(width: 6),
        Text("Có cảnh báo khác", style: TextStyle(color: neutralWeatherColor, fontSize: 13)),
      ],
    );
  }

  Widget _buildAnimatedSearchPanel(BuildContext context, MapProvider mapProvider, SettingsProvider settingsProvider) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
        axisAlignment: -1.0,
        child: _buildSearchPanel(context, mapProvider, settingsProvider),
      ),
    );
  }

  Widget _buildSearchPanel(BuildContext context, MapProvider mapProvider, SettingsProvider settingsProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSearchField(context, 'Điểm đi', _originController, true),
                const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8),
                _buildSearchField(context, 'Điểm đến', _destinationController, false),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final String origin = _originController.text.trim();
                          final String destination = _destinationController.text.trim();

                          if (origin.isEmpty || destination.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Vui lòng nhập đủ điểm đi và điểm đến.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          FocusManager.instance.primaryFocus?.unfocus();
                          final String travelMode = Provider.of<SettingsProvider>(context, listen: false).travelMode;
                          Provider.of<MapProvider>(context, listen: false).findRoute(origin, destination, travelMode, context);
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Tìm đường'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _originController.clear();
                          _destinationController.clear();
                        });
                      },
                      child: const Icon(Icons.refresh),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, String hint, TextEditingController controller, bool isOrigin) {
    return InkWell(
      onTap: () => _navigateToSearchScreen(context, isOrigin),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isOrigin ? Icons.trip_origin : Icons.flag, size: 18, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.text.isEmpty ? hint : controller.text,
                style: TextStyle(fontSize: 15, color: controller.text.isEmpty ? Theme.of(context).hintColor : Theme.of(context).textTheme.bodyLarge?.color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOrigin)
              IconButton(
                icon: const Icon(Icons.my_location),
                tooltip: 'Chọn vị trí hiện tại',
                onPressed: () {
                  setState(() {
                    controller.text = 'Vị trí của bạn';
                  });
                },
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context, MapProvider mapProvider) {

    return Positioned(
      bottom: 15,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_toggle',
            tooltip: _isSearchPanelVisible ? 'Ẩn tìm kiếm' : 'Hiện tìm kiếm',
            onPressed: () => setState(() {
              _isSearchPanelVisible = !_isSearchPanelVisible;
              if (_isSearchPanelVisible) {
                _animCtrl.forward();
              } else {
                _animCtrl.reverse();
              }
            }),
            child: Icon(_isSearchPanelVisible ? Icons.keyboard_arrow_up : Icons.search),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 4,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'fab_location',
            tooltip: 'Vị trí của tôi',
            onPressed: () => mapProvider.animateToCurrentLocation(),
            child: const Icon(Icons.my_location),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 4,
          ),
          const SizedBox(height: 8),

          FloatingActionButton.small(
            heroTag: 'fab_traffic',
            tooltip: 'Giao thông',
            backgroundColor: mapProvider.trafficEnabled ? Colors.blue[700] : Theme.of(context).colorScheme.surface,
            foregroundColor: mapProvider.trafficEnabled ? Colors.white : Theme.of(context).colorScheme.onSurface,
            onPressed: () => mapProvider.toggleTrafficLayer(),
            child: const Icon(Icons.traffic),
          ),
          FloatingActionButton.small(
            heroTag: 'fab_fav',
            tooltip: 'Lộ trình ưa thích',

            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);

              if (authProvider.isAuthenticated) {
                setState(() {
                  if (!_isSearchPanelVisible) {
                    _isSearchPanelVisible = true;
                    _animCtrl.forward();
                  }
                });
                _showFavoriteRoutesBottomSheet(context, mapProvider);
              } else {
                _showLoginRequiredDialog();
              }
            },

            child: const Icon(Icons.star),
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 4,
          ),
          if (mapProvider.polylines.isNotEmpty) ...[
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'fab_save',
              tooltip: 'Lưu lộ trình',
              onPressed: () {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);

                if (authProvider.isAuthenticated) {
                  _showSaveRouteDialog(context, mapProvider);
                } else {
                  _showLoginRequiredDialog();
                }
              },
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              child: const Icon(Icons.favorite),
              elevation: 6,
            ),
          ]
        ],
      ),
    );
  }

  void _showFavoriteRoutesBottomSheet(BuildContext context, MapProvider mapProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.8,
          builder: (BuildContext context, ScrollController scrollController) {
            return Column(
              children: [
                Container(width: 40, height: 5, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
                Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text('Lộ trình ưa thích', style: Theme.of(context).textTheme.titleLarge)),
                const Divider(height: 1),
                Expanded(
                  child: Consumer<MapProvider>(
                    builder: (context, provider, child) {
                      if (provider.favoriteRoutes.isEmpty) {
                        return const Center(child: Text('Lưu một lộ trình để xem lại nhanh hơn.'));
                      }
                      return ListView.separated(
                        controller: scrollController,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: provider.favoriteRoutes.length,
                        itemBuilder: (context, index) {
                          final route = provider.favoriteRoutes[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.star, color: Colors.amber[700]),
                            ),
                            title: Text(route['label']),
                            subtitle: Text(
                              '${route['originAddress']} → ${route['destinationAddress']}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () {
                              Navigator.pop(context);
                              _showDeleteConfirmationDialog(context, provider, route);
                            }),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                _originController.text = route['originAddress'];
                                _destinationController.text = route['destinationAddress'];
                              });

                              // provider.findRoute(_originController.text, _destinationController.text, Provider.of<SettingsProvider>(context, listen: false).travelMode, context);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSaveRouteDialog(BuildContext context, MapProvider mapProvider) {
    final String origin = _originController.text.trim();
    final String destination = _destinationController.text.trim();

    if (origin.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn điểm đi và điểm đến trước khi lưu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final labelController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lưu lộ trình ưa thích'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: labelController,
            decoration: const InputDecoration(hintText: 'Ví dụ: Đường đến công ty'),
            validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập tên' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final originMarker = mapProvider.markers.firstWhere((m) => m.markerId.value == 'origin');
                final destMarker = mapProvider.markers.firstWhere((m) => m.markerId.value == 'destination');
                final routeData = {
                  'label': labelController.text,
                  'originAddress': _originController.text,
                  'originLatitude': originMarker.position.latitude,
                  'originLongitude': originMarker.position.longitude,
                  'destinationAddress': _destinationController.text,
                  'destinationLatitude': destMarker.position.latitude,
                  'destinationLongitude': destMarker.position.longitude,
                };
                mapProvider.addFavoriteRoute(routeData);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu lộ trình!')));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, MapProvider provider, dynamic route) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa lộ trình?'),
        content: Text('Bạn có chắc chắn muốn xóa lộ trình "${route['label']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              provider.deleteFavoriteRoute(route['id']);
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationFab(BuildContext context, MapProvider mapProvider) {
    final isTracking = mapProvider.isNavigating;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(isTracking),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: isTracking
                  ? Colors.redAccent.withOpacity(0.3)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: isTracking
              ? mapProvider.stopVoiceTracking
              : mapProvider.launchGoogleMapsNavigation,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
            backgroundColor: isTracking
                ? Colors.redAccent
                : Theme.of(context).colorScheme.primary,
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (isTracking) return Colors.redAccent;
              return states.contains(WidgetState.pressed)
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                  : null;
            }),
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isTracking
                ? const Icon(Icons.stop_circle_outlined, key: ValueKey('stop'))
                : const Icon(Icons.navigation_rounded, key: ValueKey('nav')),
          ),
          label: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              isTracking ? 'Dừng theo dõi' : 'Bắt đầu theo dõi',
              key: ValueKey(isTracking),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernLegend extends StatelessWidget {
  const _ModernLegend({super.key});

  Widget _legendChip(String label, Color color, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8, bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))],
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.2))),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chú giải thời tiết', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            Wrap(
              children: [
                _legendChip('Thời tiết tốt', const Color(0xFF43A047), context),
                _legendChip('Cảnh báo nhẹ', const Color(0xFFFF9800), context),
                _legendChip('Nguy hiểm', const Color(0xFFFA0606), context),
              ],
            )
          ],
        ),
      ),
    );
  }
}