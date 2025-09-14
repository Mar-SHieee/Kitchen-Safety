#include <Arduino.h>
#include <DHT.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

// --- Pins ---
#define PIN_MQ2    34
#define PIN_DHT    15
#define PIN_FLAME  35
#define PIN_SERVO  14
#define PIN_LED    25
#define PIN_BUZZ   26

// --- DHT ---
#define DHTTYPE DHT11
DHT dht(PIN_DHT, DHTTYPE);

// --- Servo ---
Servo myServo;
int servoPos = 0;  

// --- LCD ---
LiquidCrystal_I2C lcd(0x27, 16, 2);

// --- WiFi ---
const char* ssid = "!^Beshny^!";
const char* password = "_!@#Bbeshny1";

// HiveMQ
const char* mqtt_server = "f397af5cc99248cda55980326253181b.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_user = "Mar_Shieee";
const char* mqtt_password = "Marammarshiemaram2005";

// Topics
const char* sub_led   = "led";
const char* pub_led   = "led/confirm";
const char* sub_servo = "servo";
const char* pub_servo = "servo/confirm";
const char* sub_buzz  = "buzzer";
const char* pub_buzz  = "buzzer/confirm";
const char* pub_sensors = "sensors/data";

WiFiClientSecure secureClient;
PubSubClient client(secureClient);

// --- Supabase ---
const char* SUPABASE_URL = "https://recsbpbfmvzqillzqasa.supabase.co/rest/v1/sensors";
const char* SUPABASE_API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlY3NicGJmbXZ6cWlsbHpxYXNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ3MjIxODYsImV4cCI6MjA3MDI5ODE4Nn0.DJOEtld0vWqPMbp91OkZqtD2vI3DVmFRV6RGUGLtxI4";

// ================== SEND TO SUPABASE ==================
void sendToSupabase(String jsonData) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(SUPABASE_URL);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("apikey", SUPABASE_API_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_API_KEY);

    int httpResponseCode = http.POST(jsonData);

    if (httpResponseCode > 0) {
      Serial.printf("Supabase response code: %d\n", httpResponseCode);
      String response = http.getString();
      Serial.println("Response: " + response);
    } else {
      Serial.printf("Error sending to Supabase: %s\n",
                    http.errorToString(httpResponseCode).c_str());
    }

    http.end();
  } else {
    Serial.println("WiFi not connected!");
  }
}

// ================== CALLBACK ==================
void callback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();
  Serial.printf("Received [%s]: %s\n", topic, msg.c_str());

  if (String(topic) == sub_led) {
    if (msg == "ON") {
      digitalWrite(PIN_LED, HIGH);
      client.publish(pub_led, "LED ON");
    } else {
      digitalWrite(PIN_LED, LOW);
      client.publish(pub_led, "LED OFF");
    }
  }

  if (String(topic) == sub_servo) {
    int angle = msg.toInt();
    angle = constrain(angle, 0, 180);
    myServo.write(angle);
    servoPos = angle;  
    delay(1000);  
    String confirm = "Servo moved to " + String(angle);
    client.publish(pub_servo, confirm.c_str());
  }

  if (String(topic) == sub_buzz) {
    if (msg == "ON") {
      digitalWrite(PIN_BUZZ, HIGH);
      client.publish(pub_buzz, "Buzzer ON");
    } else {
      digitalWrite(PIN_BUZZ, LOW);
      client.publish(pub_buzz, "Buzzer OFF");
    }
  }
}

// ================== RECONNECT ==================
void reconnect() {
  while (!client.connected()) {
    Serial.println("Attempting MQTT connection...");
    if (client.connect("ESP32Client", mqtt_user, mqtt_password)) {
      Serial.println("MQTT connected");
      client.subscribe(sub_led);
      client.subscribe(sub_servo);
      client.subscribe(sub_buzz);
    } else {
      Serial.print("Failed. State=");
      Serial.print(client.state());
      Serial.println(" Retrying in 5 seconds...");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);

  pinMode(PIN_MQ2, INPUT);
  pinMode(PIN_FLAME, INPUT);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUZZ, OUTPUT);

  dht.begin();
  myServo.attach(PIN_SERVO);
  myServo.write(0);  
  servoPos = 0;

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Smart Kitchen");
  delay(1500);
  lcd.clear();

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");

  secureClient.setInsecure();  
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  int gasValue = analogRead(PIN_MQ2);
  int flameValue = analogRead(PIN_FLAME);
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  Serial.print("Temp: "); Serial.print(temp);
  Serial.print(" °C | Hum: "); Serial.print(hum);
  Serial.print(" % | Gas: "); Serial.print(gasValue);
  Serial.print(" | Flame: "); Serial.println(flameValue);

  bool flameDanger = (flameValue < 1000);
  bool gasDanger   = (gasValue > 2000);
  bool tempDanger  = (temp > 40);

  bool danger = gasDanger || flameDanger || tempDanger;

  if (danger) {
    digitalWrite(PIN_LED, HIGH);
    digitalWrite(PIN_BUZZ, HIGH);
    myServo.write(180); 
    servoPos = 180;
    Serial.println("⚠ DANGER detected! Door opened to 180°");
    
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("DANGER! EVACUATE");
    lcd.setCursor(0, 1);
    String dangerMsg = "";
    if (gasDanger)   dangerMsg += "Gas ";
    if (flameDanger) dangerMsg += "Fire ";
    if (tempDanger)  dangerMsg += "Heat ";
    lcd.print(dangerMsg);
  } else {
    digitalWrite(PIN_LED, LOW);
    digitalWrite(PIN_BUZZ, LOW);
    myServo.write(0);  
    servoPos = 0;
    Serial.println("✅ Safe - Door closed at 0°");
    
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("T:"); lcd.print(temp, 1);
    lcd.print("C H:"); lcd.print(hum, 0); lcd.print("%");
    lcd.setCursor(0, 1);
    lcd.print("G:"); lcd.print(gasValue);
    lcd.print(" F:");
    if (flameDanger) lcd.print("FIRE!");
    else lcd.print("Safe");
  }

  // --- JSON data for MQTT & Supabase ---
  String sensorData = "{";
  sensorData += "\"temp\":" + String(temp) + ",";
  sensorData += "\"hum\":" + String(hum) + ",";
  sensorData += "\"gas\":" + String(gasValue) + ",";
  sensorData += "\"flame\":" + String(flameValue) + ",";
  sensorData += "\"led\":" + String(digitalRead(PIN_LED)) + ",";
  sensorData += "\"buzzer\":" + String(digitalRead(PIN_BUZZ)) + ",";
  sensorData += "\"servo\":" + String(servoPos) + ",";  // استخدام servoPos المحدث
  if (danger) {
    sensorData += "\"status\":\"DANGER - Door Open\"";
  } else {
    sensorData += "\"status\":\"All Safe\"";
  }
  sensorData += "}";

  // --- Publish to MQTT ---
  client.publish(pub_sensors, sensorData.c_str());

  // --- Send to Supabase ---
  sendToSupabase(sensorData);

  delay(5000);
}