## ESP32 Firmware

- **Sensor Reading**: Continuous monitoring of MQ2, flame sensor, and DHT11 every second.
- **Threshold Checking**: Compares readings against safety thresholds and determines status.
- **Actuator Control**: Automatically triggers LED, buzzer, and servo based on danger conditions.
- **LCD Updates**: Displays current sensor readings and system status with rotating information.
- **Cloud Communication**: #Sends 🍳 Smart Kitchen Safety - IoT Solution for Modern Homes

> **Transforming Kitchen Safety Through Smart Technology**

Welcome to **Smart Kitchen Safety**, a cutting-edge IoT solution that revolutionizes kitchen safety monitoring and control. Developed by passionate students at the Faculty of Computing and Data Science, Alexandria University, this project combines the power of **Flutter mobile development**, **ESP32 microcontrollers**, and **real-time IoT communication** to create a comprehensive safety ecosystem for modern kitchens.

Our mission is simple yet powerful: **Prevent kitchen accidents before they happen**. Through continuous monitoring of gas levels, flame detection, temperature, and humidity, combined with intelligent automated responses, we're making kitchens safer, smarter, and more connected than ever before.

---

## Table of Contents

1. [Features](#features)
2. [Contribution to SDGs](#contribution-to-sdgs)
3. [System Architecture](#system-architecture)
4. [Flutter App Pages](#flutter-app-pages)
5. [Core Services](#core-services)
6. [Supabase Database Structure](#supabase-database-structure)
7. [ESP32 Firmware](#esp32-firmware)
8. [Sensor Thresholds](#sensor-thresholds)
9. [File Structure](#file-structure)
10. [Setup Instructions](#setup-instructions)
11. [Security Considerations](#security-considerations)
12. [Future Improvements](#future-improvements)
13. [Technologies Used](#technologies-used)
14. [Demo & Resources](#demo--resources)
15. [Contributing](#contributing)
16. [License](#license)

---

## Features

- **Secure Authentication**: User signup/login with email, password, and username via Supabase (`auth_service.dart`, `auth_screen.dart`).
- **Real-time Monitoring**: Displays live sensor readings (gas, flame, temperature, humidity) with status updates (`Safe`, `Warning`, `Danger`) on the app (`live_status_screen.dart`, `view_sensors_page.dart`) and ESP32 LCD (`KitchenSafetyESP.ino`).
- **Sensor Management**: Add/delete up to 4 sensors (`add_sensor_page.dart`, `delete_sensor_page.dart`).
- **Customizable Alerts**: Enable notifications (with/without vibration) and control actuators (LED, buzzer, servo) via MQTT (`alerts_page.dart`).
- **Local Notifications**: Triggers alerts with vibration and sound for danger conditions (`notification_service.dart`).
- **Historical Logs**: View sensor data history with timestamps and statuses (`sensor_logs_screen.dart`).
- **Responsive UI**: Modern design with animations (pulse, fade, slide) and consistent themes (`app_theme.dart`, `app_models.dart`).
- **ESP32 Integration**: Collects sensor data, controls actuators, and displays status on a 16x2 LCD (`KitchenSafetyESP.ino`).

---

## Contribution to SDGs

- **SDG 3: Good Health and Well-Being**: Prevents health hazards like gas poisoning, burns, or respiratory issues through early detection and automatic safety responses.
- **SDG 11: Sustainable Cities and Communities**: Enhances home safety for safer urban environments by providing smart monitoring and preventive measures.
- **SDG 9: Industry, Innovation, and Infrastructure**: Advances smart home technology via IoT integration, contributing to modern infrastructure development.

---

## System Architecture

- **Frontend (Flutter)**: StatefulWidgets for dynamic UI; Provider/setState for state management with real-time updates via MQTT.
- **Backend (Supabase)**: Authentication, data storage, real-time subscriptions (`supabase_service.dart`) with PostgreSQL database.
- **MQTT**: Real-time IoT communication via Singleton pattern (`mqtt_service.dart`) and ESP32 (`KitchenSafetyESP.ino`).
- **Local Notifications**: Multiple channels (danger, warning, info) with vibration and sound (`notification_service.dart`).
- **Embedded System (ESP32)**: Collects sensor data, controls LED, buzzer, and servo, displays on LCD, communicates with Supabase/MQTT.
- **Data Models**: Defined in `app_models.dart` (e.g., SensorType, SensorStatus, SystemStatus, Sensor, SensorLog, AlertSettings).

---

## Flutter App Pages

### Splash Screen (`splash_screen.dart`)
- **Welcome Animation**: Displays "Smart Kitchen" with kitchen-themed background for 2 seconds.
- **App Initialization**: Preloads assets and initializes services before navigation.
- **Smooth Transition**: Automated navigation to authentication screen with fade animation.

### Authentication Screen (`auth_screen.dart`)
- **Dual Mode Interface**: Toggle between Sign In and Sign Up with animated transitions.
- **Form Validation**: Real-time email, password, and username validation with error messages.
- **Supabase Integration**: Secure registration updates `profiles` table, login redirects to Dashboard.
- **Error Handling**: User-friendly error messages for authentication failures.

### Dashboard (`dashboard.dart`)
- **Real-time Banner**: Shows live sensor readings via MQTT with color-coded status indicators.
- **Dynamic Sensor Cards**: Up to 4 sensor cards (gas, flame, temp, hum) with live data updates.
- **Danger Indicators**: Red shadow applied to cards during danger conditions with pulse animation.
- **Navigation Hub**: Quick access buttons to Add Sensor, Delete Sensor, View Sensors, and Alerts pages.
- **MQTT Status**: Connection indicator showing real-time communication status.

### Add Sensor Page (`add_sensor_page.dart`)
- **Sensor Type Selection**: Choose from Gas, Flame, Temperature, or Humidity sensors.
- **Validation Logic**: Prevents adding more than 4 sensors per user with clear feedback.
- **Database Integration**: Updates `user_sensors` table with new sensor assignments.
- **Success Feedback**: Confirmation messages and automatic navigation back to dashboard.

### Delete Sensor Page (`delete_sensor_page.dart`)
- **Current Sensors List**: Shows all user-assigned sensors with delete options.
- **Confirmation Dialogs**: Prevents accidental deletion with "Are you sure?" prompts.
- **Cascade Deletion**: Removes sensor from `user_sensors` and cleans related data.
- **Real-time Updates**: Immediate UI refresh after successful deletion.

### Alerts Configuration (`alerts_page.dart`)
- **Per-Sensor Controls**: Individual notification toggles for Gas, Flame, Temperature, and Humidity.
- **Vibration Settings**: Enable/disable vibration for each sensor type independently.
- **Manual Actuator Control**: Direct LED, Buzzer, and Servo control via MQTT commands.
- **Offline Handling**: Disables notifications for sensors not currently active.
- **Settings Persistence**: Saves preferences using SharedPreferences for app restart retention.

### Live Status Screen (`live_status_screen.dart`)
- **Real-time Display**: Continuously updated sensor readings with 1-second refresh rate.
- **MQTT Monitoring**: Shows connection status and last update timestamp.
- **Color-coded Status**: Green for safe, yellow for warning, red for danger conditions.
- **Manual Refresh**: Pull-to-refresh functionality for instant data updates.
- **Connection Indicators**: Visual feedback for MQTT and database connectivity.

### Sensor Logs Screen (`sensor_logs_screen.dart`)
- **Historical Data Table**: Chronological display of all sensor readings with timestamps.
- **Status Tracking**: Shows how sensor conditions changed over time.
- **Filtering Options**: Filter by sensor type, date range, or status level.
- **Export Capability**: Save logs to CSV for external analysis.
- **Pagination**: Efficient loading of large datasets with scroll-based pagination.

### View Sensors Page (`view_sensors_page.dart`)
- **User Sensor List**: Displays all sensors assigned to current user from `user_sensors`.
- **Live Integration**: Shows real-time readings for each assigned sensor.
- **Status Highlighting**: Red shadow and warning indicators for sensors in danger state.
- **Individual Monitoring**: Tap sensors for detailed view and historical data.
- **Empty State**: Friendly message when no sensors are assigned with "Add Sensor" shortcut.

---

## Core Services

### Supabase Service (`supabase_service.dart`)
- **Client Management**: Singleton pattern for Supabase client initialization with secure configuration.
- **Authentication**: Login, signup, logout, and session management with error handling.
- **Database Operations**: CRUD operations for all tables with Row Level Security enforcement.
- **Real-time Subscriptions**: Live data updates for sensors table with automatic reconnection.
- **Profile Management**: User profile creation and updates with username validation.

### MQTT Service (`mqtt_service.dart`)
- **Connection Management**: Singleton pattern with HiveMQ Cloud integration and auto-reconnection.
- **Secure Communication**: TLS encryption with username/password authentication.
- **Topic Management**: Organized topic structure for different actuator commands (led/buzzer/servo).
- **Message Handling**: JSON-based command publishing with QoS level 1 for reliable delivery.
- **Status Monitoring**: Connection state tracking with callback notifications to UI.

### Notification Service (`notification_service.dart`)
- **Multi-channel System**: Separate channels for danger, warning, and info level notifications.
- **Custom Sounds**: Danger alerts use custom sound file for immediate attention.
- **Vibration Control**: Configurable vibration patterns for different alert types.
- **Permission Handling**: Runtime permission requests with user-friendly explanations.
- **Scheduling**: Support for immediate and scheduled notifications with proper Android handling.

---

## Supabase Database Structure

### `profiles` Table
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key linked to auth.users |
| `created_at` | timestamp | Account creation timestamp |
| `username` | text | User display name (unique) |
| `active` | boolean | Account status flag |

### `sensors` Table
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Unique sensor reading identifier |
| `user_id` | uuid | Foreign key to profiles.id |
| `gas` | numeric | MQ2 gas sensor reading (0-4095) |
| `flame` | numeric | IR flame sensor value (0-4095) |
| `temp` | numeric | DHT11 temperature in Celsius |
| `hum` | numeric | DHT11 humidity percentage |
| `led` | int8 | LED state (0=off, 1=on) |
| `buzzer` | int8 | Buzzer state (0=off, 1=on) |
| `servo` | int8 | Servo position (0=closed, 180=open) |
| `status` | text | Overall system status message |

### `user_alerts` Table
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Unique alert record identifier |
| `user_id` | uuid | Foreign key to profiles.id |
| `created_at` | timestamp | Alert trigger timestamp |
| `sensor_type` | text | Type of sensor that triggered alert |
| `alert_type` | text | Notification method used |

### `user_sensors` Table
| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Unique sensor assignment identifier |
| `user_id` | uuid | Foreign key to profiles.id |
| `created_at` | timestamp | Assignment creation timestamp |
| `sensor_type` | text | Type of sensor assigned to user |

---

## ESP32 Firmware

### Hardware Configuration
```cpp
// Pin Assignments
#define MQ2_PIN 34      // Gas sensor (analog input)
#define FLAME_PIN 35    // Flame sensor (analog input)  
#define DHT_PIN 15      // DHT11 temperature/humidity sensor
#define LED_PIN 25      // Status LED (PWM capable)
#define BUZZER_PIN 26   // Alert buzzer (digital output)
#define SERVO_PIN 14    // Safety servo motor (PWM)

// I2C LCD Configuration
#define LCD_ADDR 0x27   // I2C address for 16x2 LCD
#define LCD_COLS 16     // LCD columns
#define LCD_ROWS 2      // LCD rows
```

### Main Program Flow
- **Sensor Reading**: Continuous monitoring of MQ2, flame sensor, and DHT11 every second.
- **Threshold Checking**: Compares readings against safety thresholds and determines status.
- **Actuator Control**: Automatically triggers LED, buzzer, and servo based on danger conditions.
- **LCD Updates**: Displays current sensor readings and system status with rotating information.
- **Cloud Communication**: Sends data to Supabase database and receives MQTT commands for manual control.
- **Status Management**: Maintains overall system status and sends appropriate alerts.

### LCD Display Management
- **Line 1**: Rotates between sensor readings every 2 seconds (Gas -> Flame -> Temp -> Humidity).
- **Line 2**: Shows system status ("All Safe", "WARNING", "DANGER") and WiFi/MQTT connection status.
- **Dynamic Updates**: Real-time refresh with smooth transitions between different information displays.

---

## Sensor Thresholds

| Sensor Type | Safe Range | Warning Range | Danger Threshold | Automated Response |
|-------------|------------|---------------|------------------|-------------------|
| **Gas (MQ2)** | 0 - 1500 | 1500 - 2000 | > 2000 | Buzzer ON + Red LED + Servo Open Door |
| **Flame (IR)** | > 1500 | 1000 - 1500 | < 1000 | Buzzer ON + Red LED + Servo Open Door |
| **Temperature** | < 35°C | 35°C - 40°C | > 40°C | Buzzer ON + Red LED + Servo Open Door |
| **Humidity** | < 70% | 70% - 80% | > 80% | Monitor Only (No Actuator Response) |

---

## File Structure

### Flutter App Structure
```
lib/
├── main.dart                    # App initialization, Supabase, MQTT, notifications setup
├── screens/
│   ├── splash_screen.dart       # Welcome screen with kitchen background
│   ├── auth_screen.dart         # Login/registration interface
│   ├── dashboard.dart           # Main dashboard with sensor cards and navigation
│   ├── add_sensor_page.dart     # Add sensors to user_sensors (max 4)
│   ├── delete_sensor_page.dart  # Remove sensors from user_sensors
│   ├── alerts_page.dart         # Notification settings and actuator controls
│   ├── live_status_screen.dart  # Real-time sensor data and MQTT status
│   ├── sensor_logs_screen.dart  # Historical sensor data with timestamps
│   └── view_sensors_page.dart   # List user sensors with live readings
├── services/
│   ├── auth_service.dart        # Supabase authentication management
│   ├── supabase_service.dart    # Database operations and real-time subscriptions
│   ├── mqtt_service.dart        # MQTT connection and actuator control
│   └── notification_service.dart # Local notifications with vibration
├── models/
│   └── app_models.dart          # Data models, enums, and helper functions
├── theme/
│   └── app_theme.dart           # App colors, themes, and design tokens
└── assets/
    ├── fonts/                   # Custom fonts for typography
    ├── images/                  # App images and splash screen assets
    └── sounds/                  # Custom alert sounds for notifications
```

### ESP32 Firmware Structure
```
KitchenSafetyESP/
├── KitchenSafetyESP.ino        # Main firmware file
├── config.h                    # WiFi, MQTT, and Supabase credentials
├── sensors.h                   # Sensor reading and threshold functions
├── actuators.h                 # LED, buzzer, and servo control
├── display.h                   # LCD display management
├── communication.h             # WiFi, MQTT, and HTTP communication
└── README.md                   # ESP32 setup and configuration guide
```

---

## Setup Instructions

### Flutter App Setup

#### Prerequisites
```bash
# Verify Flutter installation
flutter doctor -v

# Install dependencies
flutter pub get
```

#### Environment Configuration
Create `.env` file in project root:
```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
MQTT_BROKER_URL=your_hivemq_cloud_url
MQTT_USERNAME=your_mqtt_username
MQTT_PASSWORD=your_mqtt_password
```

#### Supabase Database Setup
1. Create new Supabase project at [supabase.com](https://supabase.com)
2. Import database schema from `/database/schema.sql`
3. Enable Row Level Security (RLS) on all tables:
   ```sql
   ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
   ALTER TABLE sensors ENABLE ROW LEVEL SECURITY;
   ALTER TABLE user_alerts ENABLE ROW LEVEL SECURITY;
   ALTER TABLE user_sensors ENABLE ROW LEVEL SECURITY;
   ```
4. Create RLS policies for user data isolation
5. Configure authentication settings and email templates

#### MQTT Broker Setup
1. Create HiveMQ Cloud account at [hivemq.com](https://www.hivemq.com/mqtt-cloud-broker/)
2. Create new cluster with TLS encryption
3. Generate username and password credentials
4. Update MQTT configuration in `.env` file

#### Run Application
```bash
# Development mode
flutter run --dart-define-from-file=.env

# Release build
flutter build apk --release --dart-define-from-file=.env
```

### ESP32 Firmware Setup

#### Hardware Assembly
```
Component Connections:
├── MQ2 Gas Sensor    → ESP32 Pin 34 (ADC1_CH6)
├── IR Flame Sensor   → ESP32 Pin 35 (ADC1_CH7)
├── DHT11 Sensor      → ESP32 Pin 15 (GPIO15)
├── Status LED        → ESP32 Pin 25 (GPIO25) + 220Ω resistor
├── Buzzer           → ESP32 Pin 26 (GPIO26) + transistor
├── Servo Motor      → ESP32 Pin 14 (GPIO14) + external power
└── I2C LCD 16x2     → SDA (GPIO21), SCL (GPIO22) + I2C pullup resistors
```

#### Arduino IDE Configuration
1. Install Arduino IDE 2.x
2. Add ESP32 board support:
   ```
   File → Preferences → Additional Board Manager URLs:
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_dev_index.json
   ```
3. Install required libraries:
   ```
   DHT sensor library by Adafruit
   LiquidCrystal_I2C by Frank de Brabander
   ESP32Servo by Kevin Harrington
   PubSubClient by Nick O'Leary
   ArduinoJson by Benoit Blanchon
   ```

#### Firmware Configuration
Update `config.h` with your credentials:
```cpp
// WiFi Configuration
const char* ssid = "your_wifi_ssid";
const char* password = "your_wifi_password";

// MQTT Configuration  
const char* mqtt_server = "your_hivemq_broker_url";
const int mqtt_port = 8883;
const char* mqtt_user = "your_mqtt_username";
const char* mqtt_password = "your_mqtt_password";

// Supabase Configuration
const char* supabase_url = "your_supabase_url";
const char* supabase_key = "your_supabase_anon_key";
```

#### Upload Firmware
1. Connect ESP32 to computer via USB
2. Select board: "ESP32 Dev Module"
3. Select correct COM port
4. Upload sketch to ESP32
5. Monitor serial output for debugging

---

## Security Considerations

### Database Security (Supabase)
- **Row Level Security (RLS)**: Enabled on all tables to ensure users can only access their own data.
- **Authentication Integration**: All database operations require valid user authentication tokens.
- **API Key Protection**: Anon key stored in environment variables, never hardcoded.
- **Secure Policies**: RLS policies prevent unauthorized data access and modification.

### MQTT Communication Security
- **TLS Encryption**: All MQTT communications use TLS 1.2+ encryption.
- **Authentication**: Username/password authentication required for broker connection.
- **Topic Security**: User-specific topics prevent cross-user command interference.
- **Credential Management**: MQTT credentials stored in secure environment configuration.

### Mobile App Security
- **Secure Storage**: Sensitive data stored using Flutter's secure storage mechanisms.
- **Input Validation**: All user inputs validated and sanitized before processing.
- **Session Management**: Automatic token refresh and secure session handling.
- **Permission Controls**: Runtime permissions requested with clear explanations.

### ESP32 Embedded Security
- **Encrypted WiFi**: WPA2/WPA3 encrypted WiFi communication.
- **Secure MQTT**: TLS-encrypted MQTT connections with certificate validation.
- **OTA Security**: Over-the-air updates with cryptographic signature verification.
- **Hardware Security**: ESP32's built-in security features for secure boot and flash encryption.

---

## Future Improvements

### Short-term Enhancements (3 months)
- **Advanced State Management**: Implement Provider or Riverpod for better scalability and performance.
- **Data Visualization**: Add interactive charts using FlChart for sensor trend analysis.
- **Offline Support**: Local data caching with SQLite for offline functionality.
- **Push Notifications**: Firebase Cloud Messaging integration for remote alerts.
- **Accessibility**: Screen reader support and improved accessibility features.

### Medium-term Goals (6-12 months)
- **Machine Learning**: Predictive analytics for early hazard detection using sensor patterns.
- **Voice Control**: Integration with Google Assistant and Amazon Alexa for voice commands.
- **Smart Home Integration**: Support for HomeKit, SmartThings, and other smart home platforms.
- **Multi-language**: Support for Arabic, French, and other languages with RTL layout.
- **Advanced Analytics**: Detailed reporting and trend analysis with export capabilities.

### Long-term Vision (1-2 years)
- **AI-powered Assistance**: Intelligent cooking recommendations and safety suggestions.
- **Community Features**: Share safety data and best practices with other users.
- **Professional Solutions**: Enterprise-grade solutions for restaurants and commercial kitchens.
- **Emergency Integration**: Direct integration with emergency services for critical situations.
- **IoT Ecosystem**: Integration with other IoT devices for comprehensive home automation.

---

## Technologies Used

### Frontend Technologies
- **Flutter 3.19+**: Cross-platform mobile app development framework
- **Dart 3.0+**: Programming language for Flutter development
- **Material Design 3**: Modern UI components and design system
- **Provider Pattern**: State management for reactive UI updates
- **Custom Animations**: Flutter's animation framework for smooth transitions

### Backend & Cloud Services
- **Supabase**: Backend-as-a-Service with PostgreSQL database
- **Supabase Auth**: User authentication and session management
- **Supabase Realtime**: Real-time database subscriptions
- **HiveMQ Cloud**: Managed MQTT broker with TLS encryption
- **Row Level Security**: Database-level security for data isolation

### Embedded & IoT Technologies
- **ESP32 DevKit v1**: WiFi-enabled microcontroller with dual-core processor
- **Arduino Framework**: C++ development environment for ESP32
- **MQTT Protocol**: Lightweight messaging protocol for IoT communication
- **I2C Communication**: Inter-device communication for LCD display
- **PWM Control**: Pulse-width modulation for LED and servo control

### Sensors & Hardware
- **MQ2 Gas Sensor**: Detects LPG, propane, methane, and other combustible gases
- **IR Flame Sensor**: Infrared-based flame detection sensor
- **DHT11**: Combined temperature and humidity sensor
- **16x2 I2C LCD**: Character display for local status information
- **SG90 Servo Motor**: Precision motor for automated door/vent control

### Development & Deployment Tools
- **Android Studio**: Primary IDE for Flutter development
- **Arduino IDE**: ESP32 firmware development and deployment
- **Git & GitHub**: Version control and collaborative development
- **Supabase Studio**: Database management and monitoring
- **HiveMQ Console**: MQTT broker monitoring and debugging

---

## Demo & Resources

### 📹 Demo Materials
- **[Complete Flutter app Demo](https://drive.google.com/drive/folders/12oEU5cZqX2h2Plt2XGMm8bk70qlduu7L?usp=sharing)**: Comprehensive video walkthrough showing all features and functionality
- **App Screenshots**: Complete UI/UX showcase with all screens and interactions
- **Hardware Demonstration**: Physical setup showing sensor integration and actuator responses
- **Real-time Monitoring**: Live demonstration of MQTT communication and database updates

### 📚 Technical Documentation
- **Database Schema**: Complete Supabase table structures with relationships and constraints
- **API Documentation**: RESTful endpoints and real-time subscription details
- **Hardware Wiring**: Detailed circuit diagrams and component specifications
- **System Architecture**: Flow diagrams showing data flow and component interactions

### 🛠️ Development Resources
- **Team Worksheet**: Project timeline, task allocation, and development milestones
- **Code Repository**: Complete source code with detailed comments and documentation
- **Wokwi Simulation**: [Online circuit simulation](https://wokwi.com) for testing hardware without physical components
- **Kitchen Maquette**: Physical prototype demonstration showing real-world application

### 🔧 Setup & Configuration Guides
- **HiveMQ Cloud Setup**: Step-by-step MQTT broker configuration with security settings
- **Supabase Configuration**: Database setup, authentication, and RLS policy creation
- **ESP32 Programming**: Firmware development guide with library installation and troubleshooting
- **Flutter Deployment**: Mobile app building and deployment for Android and iOS platforms

---

## Contributing

We welcome contributions from developers, researchers, and IoT enthusiasts! Here's how you can get involved:

### 🐛 Bug Reports
- Use [GitHub Issues](https://github.com/your-repo/smart-kitchen-safety/issues) to report bugs
- Provide detailed reproduction steps and system information
- Include screenshots or videos when applicable
- Label issues appropriately (bug, enhancement, question)

### 💡 Feature Requests
- Submit feature ideas via [GitHub Discussions](https://github.com/your-repo/smart-kitchen-safety/discussions)
- Describe the use case and expected behavior
- Consider backward compatibility and implementation complexity
- Engage with community feedback and suggestions

### 🔧 Code Contributions
1. **Fork the repository** and create a feature branch
2. **Follow coding standards** and existing architecture patterns
3. **Add comprehensive tests** for new functionality
4. **Update documentation** including README and code comments
5. **Submit pull request** with detailed description of changes

### 📖 Documentation Improvements
- Improve existing documentation clarity and accuracy
- Add code examples and usage scenarios
- Create tutorials for specific features or setups
- Translate documentation to other languages

### 🌐 Community Support
- Answer questions in GitHub Discussions
- Help troubleshoot setup and configuration issues
- Share your own implementations and improvements
- Participate in project planning and roadmap discussions

---

## License

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for complete details.

**Copyright (c) 2024 Smart Kitchen Safety Team, Alexandria University**
GitHub Repository: [Link to be added]

Contributing
Contributions are welcome! Please submit a pull request or open an issue for suggestions, bug reports, or feature requests.
License
This project is licensed under the MIT License.
