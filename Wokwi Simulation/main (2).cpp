#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <DHT.h>
#include <ESP32Servo.h>

// --- Pins ---
#define PIN_MQ2   34   // MQ2 Gas sensor (Analog)
#define PIN_DHT   15   // DHT22
#define PIN_IR    35   // Flame sensor
#define PIN_SERVO 14   // Servo motor
#define PIN_LED   12   // LED Alarm
#define PIN_BUZZ  13   // Buzzer

// --- DHT ---
#define DHTTYPE DHT22
DHT dht(PIN_DHT, DHTTYPE);

// --- LCD ---
LiquidCrystal_I2C lcd(0x27, 16, 2);

// --- Servo ---
Servo myServo;

// --- WiFi + MQTT ---
const char* ssid = "Wokwi-GUEST";
const char* password = "";
const char* mqttServer = "broker.hivemq.com";
const int mqttPort = 1883;
WiFiClient espClient;
PubSubClient client(espClient);

// --- Supabase ---
String SUPABASE_URL = "https://YOUR-PROJECT.supabase.co/rest/v1";
String SUPABASE_TABLE = "kitchen_data";
String SUPABASE_KEY = "YOUR_SERVICE_ROLE_KEY";

// --- Timing ---
unsigned long previousMillis = 0;
const long interval = 3000; 

void connectWiFi() {
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("WiFi connected");
}

void connectMQTT() {
  while (!client.connected()) {
    client.connect("ESP32Client");
    delay(500);
  }
}

void sendToSupabase(float temp, float hum, int gas, int flame) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(SUPABASE_URL + "/" + SUPABASE_TABLE);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("apikey", SUPABASE_KEY);
    http.addHeader("Authorization", "Bearer " + SUPABASE_KEY);

    String payload = "{\"temperature\": " + String(temp) +
                     ", \"humidity\": " + String(hum) +
                     ", \"gas\": " + String(gas) +
                     ", \"flame\": " + String(flame) + "}";

    int httpResponseCode = http.POST(payload);
    Serial.print("Supabase Response: ");
    Serial.println(httpResponseCode);
    http.end();
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_MQ2, INPUT);
  pinMode(PIN_IR, INPUT);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUZZ, OUTPUT);

  dht.begin();
  myServo.attach(PIN_SERVO);
  lcd.init();
  lcd.backlight();

  connectWiFi();
  client.setServer(mqttServer, mqttPort);
  connectMQTT();

  lcd.setCursor(0, 0);
  lcd.print("Smart Kitchen");
  delay(2000);
  lcd.clear();
}

void loop() {
  unsigned long currentMillis = millis();

  // Check if 30 seconds have passed
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    // Read sensors
    int gasValue = analogRead(PIN_MQ2);
    int flameValue = digitalRead(PIN_IR);
    float temp = dht.readTemperature();
    float hum = dht.readHumidity();

    // Handle invalid DHT readings
    if (isnan(temp) || isnan(hum)) {
      Serial.println("Failed to read from DHT sensor!");
      return;
    }

    // Print to Serial
    Serial.print("Temp: "); Serial.print(temp);
    Serial.print(" °C | Hum: "); Serial.print(hum);
    Serial.print(" % | Gas: "); Serial.print(gasValue);
    Serial.print(" | Flame: "); Serial.println(flameValue);

    // Update LCD
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("T:");
    lcd.print(temp, 1);
    lcd.print(" H:");
    lcd.print(hum, 1);

    lcd.setCursor(0, 1);
    lcd.print("Gas:");
    lcd.print(gasValue);
    lcd.print(" F:");
    lcd.print(flameValue);

    // Danger detection
    bool danger = (gasValue > 2000) || (flameValue == HIGH) || (temp > 40);

    if (danger) {
      digitalWrite(PIN_LED, HIGH);
      digitalWrite(PIN_BUZZ, HIGH);
      myServo.write(90);
      client.publish("kitchen/alert", "Danger Detected!");
    } else {
      digitalWrite(PIN_LED, LOW);
      digitalWrite(PIN_BUZZ, LOW);
      myServo.write(0);
      client.publish("kitchen/alert", "All Safe");
    }

    // Send to Supabase
    sendToSupabase(temp, hum, gasValue, flameValue);
  }

  // Maintain MQTT connection
  if (!client.connected()) {
    connectMQTT();
  }
  client.loop();

  // Small delay to prevent CPU overload
  delay(10);
}