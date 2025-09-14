Smart Kitchen Safety
Smart Kitchen Safety is an IoT-based solution designed to enhance kitchen safety by monitoring environmental conditions in real-time and mitigating risks through actuators. Developed during IoT training at the Faculty of Computing and Data Science, Alexandria University, this project is a collaborative effort by team members including Nada Ahmed and Nada Aseem. It integrates a Flutter mobile application with an ESP32 microcontroller, leveraging Supabase for authentication and data storage, MQTT for real-time communication, and local notifications for critical alerts.
The system monitors gas (MQ2), flame (IR sensor), temperature, and humidity (DHT11), triggering a buzzer, red LED, and servo motor (to open a door) when safety thresholds are exceeded. Data is displayed on both the mobile app and an ESP32-connected 16x2 LCD, ensuring prompt alerts for hazards like gas leaks or fires.
Table of Contents

Features
Contribution to SDGs
System Architecture
Supabase Database Structure
UX Flow Design
Thresholds
File Structure
Setup Instructions
Flutter App
ESP32 Firmware


Security Considerations
Future Improvements
Technologies Used
Demo & Resources
Contributing
License

Features

Secure Authentication: User signup/login with email, password, and username via Supabase (auth_service.dart, auth_screen.dart).
Real-time Monitoring: Displays live sensor readings (gas, flame, temperature, humidity) with status updates (Safe, Warning, Danger) on the app (live_status_screen.dart, view_sensors_page.dart) and ESP32 LCD (KitchenSafetyESP.ino).
Sensor Management: Add/delete up to 4 sensors (add_sensor_page.dart, delete_sensor_page.dart).
Customizable Alerts: Enable notifications (with/without vibration) and control actuators (LED, buzzer, servo) via MQTT (alerts_page.dart).
Local Notifications: Triggers alerts with vibration and sound for danger conditions (notification_service.dart).
Historical Logs: View sensor data history with timestamps and statuses (sensor_logs_screen.dart).
Responsive UI: Modern design with animations (pulse, fade, slide) and consistent themes (app_theme.dart, app_models.dart).
ESP32 Integration: Collects sensor data, controls actuators, and displays status on a 16x2 LCD (KitchenSafetyESP.ino).

Contribution to SDGs
This project aligns with the United Nations Sustainable Development Goals:

SDG 3: Good Health and Well-Being: Prevents health hazards like gas poisoning, burns, or respiratory issues by detecting gas leaks, fires, and overheating.
SDG 11: Sustainable Cities and Communities: Enhances home safety, contributing to safer and more resilient urban environments.
SDG 9: Industry, Innovation, and Infrastructure: Advances smart home technology through innovative IoT integration using Flutter, Supabase, and MQTT.

System Architecture

Frontend: Built with Flutter, using StatefulWidget for dynamic UI updates and Provider/setState for state management.
Backend:
Supabase: Manages authentication, data storage (profiles, user_sensors, sensors, user_alerts), and real-time subscriptions (supabase_service.dart).
MQTT: Enables real-time communication with IoT devices via a Singleton pattern (mqtt_service.dart) and ESP32 (KitchenSafetyESP.ino).
Local Notifications: Supports multiple channels (danger, warning, info) with vibration and sound (notification_service.dart).


Embedded System: ESP32 collects data from MQ2, DHT11, and IR flame sensors, controls LED, buzzer, and servo, and communicates with Supabase and MQTT (KitchenSafetyESP.ino).
Data Models: Defined in app_models.dart (e.g., SensorType, SensorStatus, SystemStatus, Sensor, SensorLog, AlertSettings).

Supabase Database Structure

profiles:
id (uuid): Links to the auth table.
created_at (timestamp): Record creation time.
username (text): User’s display name.
active (bool): Indicates account status.


sensors:
id (uuid): Unique sensor record ID.
user_id (uuid): Links to the user.
gas (numeric): Gas sensor value.
flame (numeric): Flame sensor value.
temp (numeric): Temperature value.
hum (numeric): Humidity value.
led (int8): LED state (0 or 1).
buzzer (int8): Buzzer state (0 or 1).
servo (int8): Servo angle (0 or 180).
status (text): System status (e.g., "All Safe", "DANGER - Door Open").


user_alerts:
id (uuid): Unique alert ID.
user_id (uuid): Links to the user.
created_at (timestamp): Alert creation time.
sensor_type (text): Sensor type (gas, flame, temp, hum).
alert_type (text): Notification type (e.g., "notification", "notification with vibration").


user_sensors:
id (uuid): Unique sensor assignment ID.
user_id (uuid): Links to the user.
created_at (timestamp): Assignment creation time.
sensor_type (text): Type of sensor assigned.



UX Flow Design
The Flutter app offers an intuitive and seamless user experience, ensuring effective interaction with the kitchen safety system.
Splash Screen (splash_screen.dart)

Displays "Smart Kitchen" with a kitchen-themed background for 2 seconds, then navigates to the authentication screen.

Authentication Screen (auth_screen.dart, auth_service.dart)

Sign Up: Users register with email, password, and username, updating the profiles table with username linked to the auth table via id.
Sign In: Existing users log in with email and password.
Redirects to the dashboard upon successful authentication.

Dashboard (dashboard.dart)

Banner: Displays real-time sensor readings (e.g., "T:25°C H:60% G:500 F:Safe S:Safe") from the MQTT topic sensors/data:{ "temp": value, "hum": value, "gas": value, "flame": value, "status": "text", "buzzer": 1 or 0, "servo": 180 or 0, "led": 1 or 0 }


Sensor Cards: Shows up to 4 sensors (gas, flame, temperature, humidity) based on user_sensors count, displaying name, value, and status.
Dynamic Updates: Refreshes automatically when sensors are added/deleted, reflecting changes in user_sensors.
Alert Indicator: Applies a red shadow to sensor cards during danger conditions (based on thresholds).
Navigation Buttons:
Add Sensor: Navigates to add_sensor_page.dart (max 4 sensors).
Delete Sensor: Navigates to delete_sensor_page.dart.
View Sensors: Navigates to view_sensors_page.dart.
Alerts: Navigates to alerts_page.dart.



View Sensors Page (view_sensors_page.dart)

Lists user-associated sensors from user_sensors, showing name, value, and username.
Updates dynamically when sensors are added/deleted.
Highlights danger conditions with a red shadow on sensor cards.

Live Status Screen (live_status_screen.dart)

Displays real-time sensor data and MQTT connection status ("Connected" or "Disconnected").
Shows active sensors from user_sensors, updating dynamically.
Visual Feedback:
Warning: Yellow highlight when sensor values approach thresholds (e.g., temp nearing 40°C).
Danger: Red highlight when thresholds are exceeded (e.g., gas > 2000).


Integrates with mqtt_service.dart and app_models.dart.

Sensor Logs Screen (sensor_logs_screen.dart)

Displays historical sensor data from the sensors table in a tabular format.
Updates UI when sensors are added/deleted in user_sensors (without affecting the Supabase sensors table).
Includes a banner showing system status, turning red during danger conditions.

Alerts Page (alerts_page.dart)

Notification Management:
Notifications are disabled by default and can be enabled per sensor.
Options: "notification only" or "notification with vibration", stored in user_alerts.
Danger conditions trigger notifications via notification_service.dart with vibration.


Actuator Control:
Controls servo (0°–180°), LED (on/off), and buzzer (on/off) via MQTT topics (led, servo, buzzer).
Updates are reflected in sensors and user_alerts.


Dynamic Behavior:
Offline sensors (removed from user_sensors) have disabled notifications.
Re-adding sensors re-enables notifications.


Banner: Displays current sensor values and status, with red alerts for danger.

Thresholds
Thresholds are based on sensor characteristics and safety standards:

Gas (MQ2): >2000, indicating a hazardous gas concentration (e.g., LPG, methane).
Flame (IR): <1000, indicating flame detection based on low analog values.
Temperature (DHT11): >40°C, indicating overheating risks in a kitchen.
Humidity (DHT11): >80%, monitored but not directly triggering danger alerts.

When any threshold is exceeded, the ESP32 triggers:

Buzzer: Audible alarm.
Red LED: Visual alert.
Servo: Opens the door (180°) for evacuation and ventilation.

File Structure

Flutter App:
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
