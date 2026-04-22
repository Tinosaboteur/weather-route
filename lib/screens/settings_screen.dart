import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/map_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = const FlutterSecureStorage();
  final _apiService = ApiService();

  String? _userName;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    _userName = await _storage.read(key: 'user_fullname');
    _userEmail = await _storage.read(key: 'user_email');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    Provider.of<MapProvider>(context, listen: false).reset();
    Provider.of<SettingsProvider>(context, listen: false).reset();
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            const SizedBox(height: 60),
            _buildUserCard(),
            const SizedBox(height: 30),
            _buildSettingsSection(context, isDarkMode, themeProvider),
            const SizedBox(height: 30),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              _userName?.substring(0, 1).toUpperCase() ?? '?',
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'Đang tải...',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _userEmail ?? '',
                  style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isDarkMode, ThemeProvider themeProvider) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Giao diện tối'),
            value: isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme(value);
            },
            secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Loại bản đồ'),
            trailing: DropdownButton<MapType>(
              value: settingsProvider.mapType,
              items: const [
                DropdownMenuItem(value: MapType.normal, child: Text('Thường')),
                DropdownMenuItem(value: MapType.satellite, child: Text('Vệ tinh')),
                DropdownMenuItem(value: MapType.hybrid, child: Text('Kết hợp')),
              ],
              onChanged: (MapType? newValue) {
                if (newValue != null) {
                  settingsProvider.updateMapType(newValue);
                }
              },
            ),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.directions_car),
            title: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Phương thức di chuyển'),
                DropdownButton<String>(
                  value: settingsProvider.travelMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'driving', child: Text('Ô tô')),
                    DropdownMenuItem(value: 'cycling', child: Text('Xe máy/Xe đạp')),
                    DropdownMenuItem(value: 'walking', child: Text('Đi bộ')),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      settingsProvider.updateTravelMode(newValue);
                    }
                  },
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.logout),
      label: const Text('Đăng xuất'),
      onPressed: _logout,
      style: ElevatedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onError,
          backgroundColor: Theme.of(context).colorScheme.error,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
      ),
    );
  }
}