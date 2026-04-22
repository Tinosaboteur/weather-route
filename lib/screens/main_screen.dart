import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/map_provider.dart';
import '../providers/settings_provider.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';
import 'history_screen.dart';
import 'package:intl/intl.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentPageIndex = 1;

  final List<Widget> _pages = const [
    SettingsScreen(),
    WeatherScreen(),
    MapScreen(),
    HistoryScreen(),
  ];

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'Cài đặt';
      case 1:
        String today = DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now());
        return 'Thời tiết hôm nay\n$today';
      case 2: return 'Bản đồ';
      case 3: return 'Lịch sử';
      default: return 'Weather Route';
    }
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
              Provider.of<MapProvider>(context, listen: false).reset();
              Provider.of<SettingsProvider>(context, listen: false).reset();
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

  @override
  Widget build(BuildContext context) {
    final bool showAppBar = _currentPageIndex != 2;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
        title: Text(_getAppBarTitle(_currentPageIndex)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      )
          : null,
      extendBodyBehindAppBar: true,
      body: IndexedStack(
        index: _currentPageIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPageIndex,
        onTap: (index) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);

          if (!authProvider.isAuthenticated && (index == 0 || index == 3)) {
            _showLoginRequiredDialog();
          } else {
            setState(() {
              _currentPageIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_outlined),
            activeIcon: Icon(Icons.wb_sunny),
            label: 'Thời tiết',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Bản đồ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
        ],
      ),
    );
  }
}