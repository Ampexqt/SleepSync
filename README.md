# SleepSync - Sleep Tracking & Analysis App

SleepSync is a Flutter-based mobile application designed to help users track and analyze their sleep patterns. The app provides insights into sleep quality, duration, and consistency, helping users improve their sleep habits.

## Features

- **Sleep Tracking**: Record and monitor your sleep patterns
- **Sleep Quality Analysis**: Get insights into your sleep quality
- **Weekly Overview**: View your sleep statistics over time
- **Personalized Goals**: Set and track sleep goals
- **User Authentication**: Secure sign-up and login
- **Dark Mode**: Comfortable viewing in low-light conditions

## Screenshots

*Screenshots coming soon*

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for emulator/simulator)
- Firebase account (for backend services)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/sleep_sync.git
   cd sleep_sync
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase**
   - Create a new Firebase project
   - Add Android/iOS app to your Firebase project
   - Download and add the `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files
   - Enable Email/Password authentication in Firebase Console

4. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

- `lib/`
  - `models/`: Data models
    - `sleep_data.dart`: Sleep data model
    - `user_settings.dart`: User preferences and settings
  - `screens/`: App screens
    - `home_screen.dart`: Main dashboard
    - `login_screen.dart`: User authentication
    - `signup_screen.dart`: New user registration
    - `settings_screen.dart`: App settings
    - `weekly_screen.dart`: Weekly sleep statistics
  - `services/`: Backend services
    - `auth_service.dart`: Authentication logic
    - `firestore_service.dart`: Database operations
    - `notification_service.dart`: Local notifications
  - `utils/`: Utilities and constants
    - `constants.dart`: App-wide constants
    - `helpers.dart`: Helper functions
  - `widgets/`: Reusable UI components
    - `custom_bottom_nav.dart`: Bottom navigation bar
    - `goal_tracker.dart`: Sleep goal progress
    - `premium_toast.dart`: Premium feature notifications
    - `quality_indicator.dart`: Sleep quality visualization
    - `sleep_card.dart`: Sleep session card
    - `sleep_chart.dart`: Sleep data visualization

## Dependencies

- `firebase_core`: Firebase Core
- `firebase_auth`: User authentication
- `cloud_firestore`: Cloud database
- `provider`: State management
- `shared_preferences`: Local storage
- `flutter_local_notifications`: Local notifications
- `intl`: Date and time formatting
- `fl_chart`: Data visualization

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.
