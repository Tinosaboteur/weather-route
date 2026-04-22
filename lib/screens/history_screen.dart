import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _apiService.getRouteHistoryLogs();
  }

  Future<void> _refreshHistory() async {
    setState(() {
      _historyFuture = _apiService.getRouteHistoryLogs();
    });
  }

  String _formatDateTime(String isoString) {
    try {
      DateTime dateTime = DateTime.parse(isoString);

      dateTime = dateTime.toLocal();

      return DateFormat('HH:mm, \'Ngày\' dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return isoString;
    }
  }
  String _getVietnameseLabel(String type) {
    switch (type.toUpperCase()) {
      case 'RAIN': return 'Mưa';
      case 'FOG': return 'Sương mù';
      case 'WIND': return 'Gió mạnh';
      case 'HIGH-UV': return 'UV cao';
      case 'CLOUDY': return 'Nhiều mây';
      case 'CLEAR-DAY':
      case 'CLEAR-NIGHT': return 'Trời quang';
      case 'PARTLY-CLOUDY-DAY':
      case 'PARTLY-CLOUDY-NIGHT': return 'Có mây';
      default: return type;
    }
  }


  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'RAIN':
        return Icons.water_drop;
      case 'FOG':
        return Icons.foggy;
      case 'WIND':
        return Icons.air;
      case 'HIGH-UV':
        return Icons.wb_sunny_outlined;
      case 'CLOUDY':
        return Icons.cloud;
      case 'PARTLY-CLOUDY-DAY':
      case 'PARTLY-CLOUDY-NIGHT':
        return Icons.cloud_queue;
      case 'CLEAR-DAY':
      case 'CLEAR-NIGHT':
        return Icons.wb_sunny;
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toUpperCase()) {
      case 'RAIN':
      case 'HIGH-UV':
        return Colors.redAccent;
      case 'FOG':
      case 'WIND':
        return Colors.orange;
      case 'CLEAR-DAY':
      case 'CLEAR-NIGHT':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildAlertsList(String? alertsStr) {
    if (alertsStr == null || alertsStr.isEmpty || alertsStr.contains("Không có cảnh báo")) {
      return const Text('Không có cảnh báo nào được ghi nhận.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey));
    }

    Map<String, int> alertCounts = {};
    List<String> lines = alertsStr.split('\n');

    for (var line in lines) {
      if (line.startsWith("- ") && line.contains(":")) {
        int colonIndex = line.indexOf(":");
        String type = line.substring(2, colonIndex).trim().toUpperCase();

        if (alertCounts.containsKey(type)) {
          alertCounts[type] = alertCounts[type]! + 1;
        } else {
          alertCounts[type] = 1;
        }
      }
    }

    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      children: alertCounts.entries.map((entry) {
        String type = entry.key;
        int count = entry.value;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _getColorForType(type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getColorForType(type).withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForType(type),
                color: _getColorForType(type),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                "${_getVietnameseLabel(type)} ($count)",
                style: TextStyle(
                  color: _getColorForType(type),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Lộ trình'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<dynamic>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _refreshHistory, child: const Text('Thử lại')),
                    ],
                  ),
                );
              }

              final historyLogs = snapshot.data;

              if (historyLogs == null || historyLogs.isEmpty) {
                return const Center(
                  child: Text(
                    'Chưa có lịch sử chuyến đi nào.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshHistory,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: historyLogs.length,
                  itemBuilder: (context, index) {
                    final log = historyLogs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: const Icon(Icons.route_outlined),
                        title: Text(
                          'Từ: ${log['origin']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('Đến: ${log['destination']}', overflow: TextOverflow.ellipsis),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateTime(log['createdAt']),
                                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),

                                const Text('Chi tiết thời tiết:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),

                                _buildAlertsList(log['weatherAlerts']),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}