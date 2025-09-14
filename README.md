# Smart Kitchen Safety

**Smart Kitchen Safety** is an IoT-based solution designed to enhance kitchen safety by monitoring environmental conditions in real-time and mitigating risks through actuators. Developed during IoT training at the Faculty of Computing and Data Science, Alexandria University, by team members, it integrates a Flutter mobile app with an ESP32 microcontroller, leveraging **Supabase**, **MQTT**, and local notifications.

---

## Table of Contents

1. [Features](#features)  
2. [Contribution to SDGs](#contribution-to-sdgs)  
3. [System Architecture](#system-architecture)  
4. [Supabase Database Structure](#supabase-database-structure)  
5. [UX Flow Design](#ux-flow-design)  
6. [Thresholds](#thresholds)  
7. [File Structure](#file-structure)  
8. [Setup Instructions](#setup-instructions)  
9. [ESP32 Firmware](#esp32-firmware)  
10. [Security Considerations](#security-considerations)  
11. [Future Improvements](#future-improvements)  
12. [Technologies Used](#technologies-used)  
13. [Demo & Resources](#demo--resources)  
14. [Contributing](#contributing)  
15. [License](#license)  

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

- **SDG 3: Good Health and Well-Being**: Prevents health hazards like gas poisoning, burns, or respiratory issues.  
- **SDG 11: Sustainable Cities and Communities**: Enhances home safety for safer urban environments.  
- **SDG 9: Industry, Innovation, and Infrastructure**: Advances smart home technology via IoT integration.  

---

## System Architecture

- **Frontend (Flutter)**: StatefulWidgets for dynamic UI; Provider/setState for state management.  
- **Backend (Supabase)**: Authentication, data storage, real-time subscriptions (`supabase_service.dart`).  
- **MQTT**: Real-time IoT communication via Singleton pattern (`mqtt_service.dart`) and ESP32 (`KitchenSafetyESP.ino`).  
- **Local Notifications**: Multiple channels (danger, warning, info) with vibration and sound (`notification_service.dart`).  
- **Embedded System (ESP32)**: Collects sensor data, controls LED, buzzer, and servo, displays on LCD, communicates with Supabase/MQTT.  
- **Data Models**: Defined in `app_models.dart` (e.g., SensorType, SensorStatus, SystemStatus, Sensor, SensorLog, AlertSettings).  

---

## Supabase Database Structure

### `profiles`

| Column     | Type       | Description                     |
|------------|------------|---------------------------------|
| id         | uuid       | Links to auth table             |
| created_at | timestamp  | Record creation time            |
| username   | text       | User display name               |
| active     | bool       | Account status                  |

### `sensors`

| Column   | Type     | Description                                    |
|----------|----------|-----------------------------------------------|
| id       | uuid     | Unique sensor ID                               |
| user_id  | uuid     | Linked to user                                 |
| gas      | numeric  | Gas sensor value                               |
| flame    | numeric  | Flame sensor value                             |
| temp     | numeric  | Temperature value                              |
| hum      | numeric  | Humidity value                                 |
| led      | int8     | LED state (0 or 1)                             |
| buzzer   | int8     | Buzzer state (0 or 1)                          |
| servo    | int8     | Servo angle (0 or 180)                         |
| status   | text     | System status (e.g., "All Safe", "DANGER")    |

### `user_alerts`

| Column      | Type      | Description                              |
|------------|-----------|------------------------------------------|
| id         | uuid      | Unique alert ID                           |
| user_id    | uuid      | Linked to user                            |
| created_at | timestamp | Alert creation time                        |
| sensor_type| text      | Sensor type (gas, flame, temp, hum)      |
| alert_type | text      | Notification type (e.g., "notification with vibration") |

### `user_sensors`

| Column      | Type      | Description                              |
|------------|-----------|------------------------------------------|
| id         | uuid      | Unique sensor assignment ID              |
| user_id    | uuid      | Linked to user                            |
| created_at | timestamp | Assignment creation time                  |
| sensor_type| text      | Type of sensor assigned                   |

---

## UX Flow Design

### Splash Screen
- Displays "Smart Kitchen" with kitchen-themed background for 2 seconds, then navigates to authentication.

### Authentication Screen
- **Sign Up**: Register with email, password, username. Updates `profiles` table.  
- **Sign In**: Existing users log in with email/password. Redirects to Dashboard.  

### Dashboard
- Banner shows real-time sensor readings via MQTT.  
- Sensor Cards show up to 4 sensors (gas, flame, temp, hum).  
- Red shadow applied to cards during danger conditions.  
- Navigation Buttons: Add Sensor, Delete Sensor, View Sensors, Alerts.

### View Sensors Page
- Lists user-associated sensors.  
- Highlights danger conditions with red shadow.  

### Live Status Screen
- Shows real-time sensor data and MQTT connection status.  
- Visual feedback: yellow for warning, red for danger.  

### Sensor Logs Screen
- Historical sensor data table.  
- Banner reflects system status.  

### Alerts Page
- Notification management: enable/disable per sensor.  
- Actuator control: LED, buzzer, servo via MQTT.  
- Offline sensors have notifications disabled.

---

## Thresholds

| Sensor Type | Threshold Value | Action on Exceeding                  |
|-------------|----------------|------------------------------------|
| Gas (MQ2)   | >2000          | Buzzer, Red LED, Servo door open   |
| Flame (IR)  | <1000          | Buzzer, Red LED, Servo door open   |
| Temp (DHT11)| >40°C          | Buzzer, Red LED, Servo door open   |
| Humidity    | >80%           | Monitored only                      |

---

## File Structure

### Flutter App
main.dart: Initializes Supabase, MQTT, notifications, and app theme.
splash_screen.dart: Displays a welcome screen with a kitchen background.
auth_service.dart: Manages user authentication.
auth_screen.dart: UI for login and registration.
dashboard.dart: Main dashboard with dynamic sensor cards and navigation.
add_sensor_page.dart: Adds sensors to user_sensors (max 4).
delete_sensor_page.dart: Removes sensors from user_sensors.
alerts_page.dart: Configures notifications and actuator controls.
live_status_screen.dart: Shows real-time sensor data and MQTT status.
sensor_logs_screen.dart: Displays historical sensor data.
view_sensors_page.dart: Lists user-associated sensors with live readings.
supabase_service.dart: Manages Supabase client and subscriptions.
mqtt_service.dart: Handles MQTT connections and actuator control.
notification_service.dart: Manages local notifications with vibration.
app_models.dart: Defines data models, enums, and helper functions.
app_theme.dart: Defines app colors and themes (light and creamy).


ESP32 Firmware:
KitchenSafetyESP.ino: Collects sensor data, controls actuators, displays on LCD, and communicates with Supabase/MQTT.


Assets:
assets/fonts/: Custom fonts for the app.
assets/images/: Images for the splash screen and UI.
assets/sounds/: Custom alert sound for notifications.



Setup Instructions
Flutter App

Clone the Repository:git clone <repository-url>
cd kitchen-safety


Install Dependencies:flutter pub get


Configure Supabase:
Create a Supabase project and update supabase_service.dart with supabaseUrl and supabaseAnonKey.
Set up tables: profiles, user_sensors, sensors, user_alerts.
Enable Row Level Security (RLS) for secure data access.


Configure MQTT:
Set up an MQTT broker (e.g., HiveMQ Cloud) and update mqtt_service.dart with broker URL, port, username, and password.
Secure credentials using a .env file with flutter_dotenv.


Configure Notifications:
Add @mipmap/ic_launcher1 to Android resources.
Add a custom sound (alert) to android/app/src/main/res/raw for danger notifications.


Run the App:flutter run



ESP32 Firmware

Install Arduino IDE and add ESP32 board support.
Install Libraries:
DHT sensor library, LiquidCrystal_I2C, ESP32Servo, PubSubClient, WiFiClientSecure, HTTPClient.


Configure Hardware:
Connect:
MQ2 sensor (pin 34)
Flame sensor (pin 35)
DHT11 (pin 15)
LED (pin 25)
Buzzer (pin 26)
Servo (pin 14)
I2C LCD (address 0x27)




Update Credentials:
Update WiFi SSID, password, MQTT broker details, and Supabase URL/API key in KitchenSafetyESP.ino.
Secure credentials in a separate configuration file if possible.


Upload Firmware:
Upload KitchenSafetyESP.ino to the ESP32 using Arduino IDE.



Security Considerations

Supabase:
Enable Row Level Security (RLS) on all tables to restrict data access.
Store supabaseUrl and supabaseAnonKey in a .env file.


MQTT:
Secure credentials in a .env file for Flutter and a configuration file for ESP32.
Replace setInsecure with proper TLS certificates on ESP32.
Implement access control on MQTT topics to prevent unauthorized access.


Notifications:
Request notification permissions with clear user prompts.
Store notification settings securely using SharedPreferences.



Future Improvements

Implement advanced state management with Provider or Riverpod for better scalability.
Add charts for visualizing sensor trends (e.g., using FlChart).
Enhance offline support with local storage for sensor data and notifications.
Integrate push notifications via Firebase or Supabase Edge Functions.
Improve accessibility with screen reader support and localized strings.
Optimize ESP32 power consumption with sleep modes.

Technologies Used

Flutter: Cross-platform mobile development.
Supabase: Authentication, database, and real-time subscriptions.
MQTT: Real-time IoT communication.
Flutter Local Notifications: Local notifications with vibration and sound.
ESP32: Embedded system for sensor data collection and actuator control.
Arduino: Firmware development for ESP32.
Dart/C++: Programming languages for Flutter and ESP32.

Demo & Resources

Demo Video: https://drive.google.com/drive/folders/12oEU5cZqX2h2Plt2XGMm8bk70qlduu7L?usp=sharing
Resources:
App screenshots
Supabase table schemas
HiveMQ setup details
Team worksheet
Flow diagrams
Wokwi project simulation
Kitchen maquette
Additional demo explaining project components


GitHub Repository: [Link to be added]

Contributing
Contributions are welcome! Please submit a pull request or open an issue for suggestions, bug reports, or feature requests.
License
This project is licensed under the MIT License.
