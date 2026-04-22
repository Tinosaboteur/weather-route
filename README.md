# Weather Route

A multi-platform Flutter application that provides real-time weather information and route planning with location-based services.

## About

Weather Route is a comprehensive cross-platform application that combines weather data with interactive mapping and route navigation. It helps users plan their trips by providing location-aware weather forecasts and optimized route suggestions.

## Features

- **Interactive Maps**: Google Maps integration with marker clustering for efficient visualization of multiple locations
- **Route Planning**: Polyline-based route visualization and navigation guidance
- **Geolocation Services**: Real-time GPS tracking and geocoding capabilities to convert coordinates to addresses
- **Weather Information**: Location-based weather data with audio narration support
- **Authentication**: Secure user authentication with Google Sign-In
- **Text-to-Speech**: Audio playback for weather information and notifications
- **Local Notifications**: Push notifications for weather alerts and route updates
- **Data Visualization**: Charts and graphs to display weather trends
- **Multi-Theme Support**: Light and dark theme options for user preference
- **Secure Storage**: Encrypted local storage for sensitive user data
- **View History**: Track and review past routes and weather data

## Supported Platforms

- **Mobile**: iOS and Android
- **Web**: Full web support
- **Desktop**: Windows and Linux

## Getting Started

### Prerequisites

- Flutter SDK 3.7.0 or higher
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for mobile development)
- Valid Google Maps API key

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd fe
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Google Maps API keys:
   - Update Android manifest with your API key
   - Update iOS Info.plist with your API key
   - Update web/index.html with your API key

4. Run the application:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart           # Application entry point
├── screens/            # UI screens
├── providers/          # State management (Provider)
├── services/           # API and business logic services
├── models/             # Data models
├── utils/              # Utility functions and themes
└── widgets/            # Reusable UI components
```

## Key Dependencies

- **google_maps_flutter**: Interactive maps with clustering
- **geolocator**: GPS location services
- **geocoding**: Coordinate to address conversion
- **provider**: State management
- **google_sign_in**: User authentication
- **flutter_tts**: Text-to-speech conversion
- **flutter_local_notifications**: Push notifications
- **just_audio**: Audio playback
- **fl_chart**: Data visualization
- **http**: Network requests

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [Provider Documentation](https://pub.dev/packages/provider)

## License

[Specify your license here]

## Support

For issues and feature requests, please contact the development team.
