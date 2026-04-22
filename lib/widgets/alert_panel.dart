import 'package:flutter/material.dart';
import '../models/weather_alert.dart';

class AlertPanel extends StatelessWidget {
  final List<WeatherAlert> alerts;
  const AlertPanel({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.2,
      minChildSize: 0.12,
      maxChildSize: 0.5,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 3,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                'Cảnh báo thời tiết',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      title: Text(alert.message),
                      subtitle: Text('Khu vực: ${alert.location}'),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}