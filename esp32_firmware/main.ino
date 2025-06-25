
#include <Arduino.h>
#include <WiFi.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <ESPAsyncWebServer.h>
#include <AsyncTCP.h>
#include <Preferences.h>
#include <Stepper.h>

// UUIDs BLE
#define SERVICE_UUID              "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8" // Recebe credenciais
#define CHARACTERISTIC_IP_UUID    "5ecabd61-1457-4bfa-8792-262c1e4b96aa" // Envia IP

// BLE
BLECharacteristic *pWriteCharacteristic;
BLECharacteristic *pIpCharacteristic;

// WiFi
String ssid = "";
String password = "";
bool credentialsReceived = false;

// Motor de passo
int passos_por_volta = 64;
Stepper motor_passo(passos_por_volta, 8, 10, 9, 11); // IN1, IN3, IN2, IN4

// Web server
AsyncWebServer server(80);

// Flash
Preferences preferences;

class WifiCredentialsCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    String rxValue = (char *)pCharacteristic->getValue().c_str();

    if (rxValue.length() > 0) {
      Serial.println("📡 Dados recebidos via BLE:");
      Serial.println(rxValue);

      StaticJsonDocument<256> doc;
      DeserializationError error = deserializeJson(doc, rxValue);

      if (!error) {
        ssid = doc["ssid"].as<String>();
        password = doc["password"].as<String>();
        credentialsReceived = true;

        preferences.begin("wifi", false);
        preferences.putString("ssid", ssid);
        preferences.putString("password", password);
        preferences.end();

        Serial.println("✅ SSID: " + ssid);
        Serial.println("✅ Password: " + password);
      } else {
        Serial.println("❌ Erro ao fazer parse do JSON");
      }
    }
  }
};

void liberarRacao() {
  Serial.println("🔄 Liberando ração...");
  motor_passo.step(1024);
  delay(1000);
  motor_passo.step(-1024);
  delay(1000);
  Serial.println("✅ Ração liberada.");
}

void startServer() {
  server.on("/liberar", HTTP_POST, [](AsyncWebServerRequest *request){
    liberarRacao();
    request->send(200, "text/plain", "Ração liberada com sucesso!");
  });

  server.on("/reset", HTTP_POST, [](AsyncWebServerRequest *request){
    preferences.begin("wifi", false);
    preferences.clear();
    preferences.end();
    request->send(200, "text/plain", "Credenciais apagadas. Reinicie o ESP32.");
    Serial.println("🗑️ Credenciais resetadas.");
  });

  server.on("/ip", HTTP_GET, [](AsyncWebServerRequest *request){
    request->send(200, "text/plain", WiFi.localIP().toString());
  });

  server.begin();
  Serial.println("🌐 Servidor web iniciado.");
}

void connectToWifi() {
  Serial.println("🔌 Conectando ao Wi-Fi...");
  WiFi.begin(ssid.c_str(), password.c_str());

  int tentativas = 0;
  while (WiFi.status() != WL_CONNECTED && tentativas < 20) {
    delay(500);
    Serial.print(".");
    tentativas++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ Conectado!");
    Serial.println("📶 IP: " + WiFi.localIP().toString());

    if (pIpCharacteristic != nullptr) {
      String ip = WiFi.localIP().toString();
      pIpCharacteristic->setValue(ip.c_str());
      pIpCharacteristic->notify();
      Serial.println("📤 IP enviado via BLE: " + ip);
    }

    startServer();
  } else {
    Serial.println("\n❌ Falha ao conectar. Voltando ao modo BLE.");
    iniciarBLE();
  }
}

void iniciarBLE() {
  Serial.println("🔧 Iniciando BLE...");

  BLEDevice::init("ESP32_S3_BLE");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Característica de escrita (SSID + senha)
  pWriteCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pWriteCharacteristic->setCallbacks(new WifiCredentialsCallback());

  // Característica de IP
  pIpCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_IP_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pIpCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->start();

  Serial.println("🔍 Aguardando dados via BLE...");
}

void setup() {
  Serial.begin(115200);
  Serial.println("🚀 Inicializando...");

  motor_passo.setSpeed(500);

  preferences.begin("wifi", true);
  ssid = preferences.getString("ssid", "");
  password = preferences.getString("password", "");
  preferences.end();

  if (ssid != "" && password != "") {
    Serial.println("📂 Credenciais salvas:");
    Serial.println("SSID: " + ssid);
    connectToWifi();
  } else {
    Serial.println("⚠️ Nenhuma credencial salva. Iniciando BLE...");
    iniciarBLE();
  }
}

void loop() {
  if (credentialsReceived) {
    credentialsReceived = false;
    connectToWifi();
  }

  delay(1000);
}
