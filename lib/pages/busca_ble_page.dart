import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'wifi_config_page.dart'; // Certifique-se de que este arquivo existe
import 'package:wifi_iot/wifi_iot.dart';

class BuscaBLEPage extends StatefulWidget {
  @override
  _BuscaBLEPageState createState() => _BuscaBLEPageState();
}

class _BuscaBLEPageState extends State<BuscaBLEPage> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? wifiCharacteristic;
  bool isLoading = false;

  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  List<String> availableSSIDs = [];

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> scanWifi() async {
    bool isEnabled = await WiFiForIoTPlugin.isEnabled();
    if (!isEnabled) {
      await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true);
    }

    // OBS: WifiNetwork está obsoleto, considere migrar para `wifi_scan` depois
    List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();

    if (networks.isNotEmpty) {
      setState(() {
        availableSSIDs = networks
            .map((net) => net.ssid ?? "")
            .where((ssid) => ssid.isNotEmpty)
            .toList();
      });
    }
  }

  void connectToESP32() async {
  setState(() => isLoading = true);

  try {
    print("🎯 Iniciando conexão com ESP32...");
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    print("🔍 Escaneando dispositivos BLE...");

    final scanResult = await FlutterBluePlus.scanResults.firstWhere(
      (results) => results.any((r) => r.device.name == 'ESP32_S3_BLE'),
      orElse: () => [],
    );

    print("🛑 Resultados do scan: ${scanResult.length}");

    if (scanResult.isEmpty) {
      print("❌ ESP32 não encontrado no scan.");
      setState(() => isLoading = false);
      return;
    }

    FlutterBluePlus.stopScan();

    final espDevice = scanResult.firstWhere(
      (r) => r.device.name == 'ESP32_S3_BLE',
    ).device;

    print("✅ Dispositivo encontrado: ${espDevice.name}");

    connectedDevice = espDevice;

    // Garante que não existe conexão anterior
    await connectedDevice!.disconnect();
    await Future.delayed(Duration(seconds: 1));

    await connectedDevice!.connect(timeout: Duration(seconds: 5));
    print("🔌 Conectado ao ESP32");

    final services = await connectedDevice!.discoverServices();
    print("🧩 Serviços encontrados: ${services.length}");

    for (BluetoothService service in services) {
      print("🔎 Serviço UUID: ${service.uuid}");
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        print("✅ Serviço corresponde ao esperado");

        for (BluetoothCharacteristic c in service.characteristics) {
          print("🧬 Característica UUID: ${c.uuid}");
          if (c.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
            print("✅ Característica corresponde");

            wifiCharacteristic = c;

            await scanWifi();
            print("📶 Redes Wi-Fi escaneadas: ${availableSSIDs.length}");

            if (!mounted) return;
            print("📲 Indo para tela WifiConfigPage");

            setState(() => isLoading = false);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WifiConfigPage(
                  ssidList: availableSSIDs,
                  characteristic: wifiCharacteristic!,
                  device: connectedDevice!,
                ),
              ),
            );
            return;
          }
        }
      }
    }

    print("❌ Serviço ou característica não encontrados.");
    setState(() => isLoading = false);
  } catch (e) {
    print("❌ Erro ao conectar: $e");
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erro ao conectar: $e")),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Conexão Bluetooth")),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : ElevatedButton.icon(
                icon: Icon(Icons.bluetooth_searching),
                label: Text("Buscar ESP32"),
                onPressed: connectToESP32,
              ),
      ),
    );
  }
}
