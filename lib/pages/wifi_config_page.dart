import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart';

class WifiConfigPage extends StatefulWidget {
  final List<String> ssidList;
  final BluetoothCharacteristic characteristic;
  final BluetoothDevice device;

  const WifiConfigPage({
    super.key,
    required this.ssidList,
    required this.characteristic,
    required this.device,
  });

  @override
  State<WifiConfigPage> createState() => _WifiConfigPageState();
}

class _WifiConfigPageState extends State<WifiConfigPage> {
  String? selectedSSID;
  final TextEditingController passwordController = TextEditingController();
  BluetoothCharacteristic? ipCharacteristic;
  String? esp32Ip;

  @override
  void initState() {
    super.initState();
    _carregarIpSalvo();   // Carrega IP salvo localmente
    buscarIpViaBLE();     // Começa a escutar IP via BLE
  }

  Future<void> _carregarIpSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final ipSalvo = prefs.getString('esp32Ip');
    if (ipSalvo != null && ipSalvo.isNotEmpty) {
      setState(() {
        esp32Ip = ipSalvo;
        globalEsp32Ip = ipSalvo;
      });
    }
  }

  Future<void> sendCredentials() async {
    if (selectedSSID == null || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione uma rede e preencha a senha")),
      );
      return;
    }

    final jsonData = jsonEncode({
      'ssid': selectedSSID,
      'password': passwordController.text,
    });

    try {
      final canWriteWithoutResponse =
          widget.characteristic.properties.writeWithoutResponse;
      final canWriteWithResponse = widget.characteristic.properties.write;

      if (canWriteWithoutResponse) {
        await widget.characteristic.write(
          utf8.encode(jsonData),
          withoutResponse: true,
        );
      } else if (canWriteWithResponse) {
        await widget.characteristic.write(
          utf8.encode(jsonData),
          withoutResponse: false,
        );
      } else {
        throw Exception("A característica não suporta escrita");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Credenciais enviadas ao ESP32")),
      );

      // Espera o ESP conectar ao Wi-Fi e enviar o IP
      await Future.delayed(const Duration(seconds: 6));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao enviar: $e")),
      );
    }
  }

  Future<void> buscarIpViaBLE() async {
    try {
      final services = await widget.device.discoverServices();

      for (var service in services) {
        for (var charac in service.characteristics) {
          if (charac.uuid.toString().toLowerCase() ==
              "5ecabd61-1457-4bfa-8792-262c1e4b96aa") {
            ipCharacteristic = charac;

            await ipCharacteristic!.setNotifyValue(true);

            ipCharacteristic!.value.listen((value) async {
              if (value.isNotEmpty) {
                final ip = utf8.decode(value).trim();

                setState(() {
                  esp32Ip = ip;
                  globalEsp32Ip = ip;
                });

                // Salvar IP localmente para persistência
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('esp32Ip', ip);

                print("📶 IP do ESP32 recebido via BLE: $ip");

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("IP do ESP32: $ip")),
                );
              }
            });

            return;
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Característica de IP não encontrada.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao buscar IP: $e")),
      );
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Selecionar Wi-Fi")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text("Escolha uma rede Wi-Fi"),
              value: selectedSSID,
              onChanged: (value) => setState(() => selectedSSID = value),
              items: widget.ssidList
                  .map((ssid) => DropdownMenuItem(
                        value: ssid,
                        child: Text(ssid),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text("Enviar para o ESP32"),
              onPressed: sendCredentials,
            ),
            const SizedBox(height: 20),
            if (esp32Ip != null)
              Text(
                "IP do ESP32: $esp32Ip",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
