import 'package:flutter/material.dart';
import 'dart:async';
import 'globals.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({Key? key}) : super(key: key);

  @override
  _MenuPrincipalState createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  double quantidadeAtual = 0.0;
  String proximaRefeicao = "Calculando...";
  String proximoReabastecimento = "Calculando...";
  Timer? _timer;
  List<String> horariosAlimentacao = [];
  double porcao = 0.0;
  Set<String> horariosLiberadosHoje = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDados();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _atualizarInformacoes();
      _verificarEExecutarRefeicao();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('horarios_alimentacao')
            .doc(user.uid)
            .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        horariosAlimentacao = List<String>.from(data['horarios'] ?? []);
        porcao = (data['porcao'] as num).toDouble();
        quantidadeAtual = (data['quantidadeAtual'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  Future<void> _salvarQuantidadeAtual() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('horarios_alimentacao')
        .doc(user.uid)
        .update({'quantidadeAtual': quantidadeAtual});
  }

  void _atualizarInformacoes() {
    setState(() {
      proximaRefeicao = _calcularProximaRefeicao();
      proximoReabastecimento = _calcularProximoReabastecimento();
    });
  }

  void _verificarEExecutarRefeicao() {
    final agora = DateTime.now();
    final horaAtual = agora.hour.toString().padLeft(2, '0');
    final minutoAtual = agora.minute.toString().padLeft(2, '0');
    final horarioAtual = "$horaAtual:$minutoAtual";

    if (horariosAlimentacao.contains(horarioAtual) &&
        !horariosLiberadosHoje.contains(horarioAtual)) {
      _liberarRacao(porAutomacao: true);
      horariosLiberadosHoje.add(horarioAtual);
    }

    // Resetar à meia-noite
    if (agora.hour == 0 && agora.minute == 0 && agora.second < 2) {
      horariosLiberadosHoje.clear();
    }
  }

  String _calcularProximaRefeicao() {
    final agora = DateTime.now();
    DateTime? proximoHorario;

    for (var horario in horariosAlimentacao) {
      final partes = horario.split(':');
      if (partes.length < 2) continue;

      final hora = int.tryParse(partes[0]) ?? 0;
      final minuto = int.tryParse(partes[1]) ?? 0;

      DateTime hoje = DateTime(
        agora.year,
        agora.month,
        agora.day,
        hora,
        minuto,
      );

      if (!hoje.isAfter(agora)) {
        hoje = hoje.add(const Duration(days: 1));
      }

      if (proximoHorario == null || hoje.isBefore(proximoHorario)) {
        proximoHorario = hoje;
      }
    }

    if (proximoHorario == null) {
      return "Nenhum horário cadastrado";
    }

    return _formatarDuracao(proximoHorario.difference(agora));
  }

  String _formatarDuracao(Duration duration) {
    int totalMinutes = duration.inMinutes;

  // Se sobrar segundos, arredonda pra cima adicionando mais 1 minuto
    if (duration.inSeconds % 60 != 0) {
      totalMinutes += 1;
    } 

    final horas = totalMinutes ~/ 60;
    final minutos = totalMinutes % 60;

    return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}H';
  }


  String _calcularProximoReabastecimento() {
    if (quantidadeAtual <= 0) return "Reabastecimento necessário!";
    if (porcao <= 0 || horariosAlimentacao.isEmpty) return "Indefinido";

    final consumoDiario = horariosAlimentacao.length * porcao / 1000;
    final diasRestantes = quantidadeAtual / consumoDiario;

    final dias = diasRestantes.floor();
    final horas = ((diasRestantes - dias) * 24).round();

    return dias > 0
        ? "$dias dia${dias > 1 ? 's' : ''} e $horas hora${horas > 1 ? 's' : ''}"
        : "$horas hora${horas > 1 ? 's' : ''}";
  }

  Future<void> _liberarRacao({bool porAutomacao = false}) async {
    final ipAddress = globalEsp32Ip;

    if (ipAddress == null || ipAddress.isEmpty) {
      if (!porAutomacao) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "IP do ESP32 não encontrado. Conecte-se via BLE primeiro.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://$ipAddress/liberar'),
        body: {'quantidade': porcao.toStringAsFixed(1)},
      );

      if (response.statusCode == 200) {
        setState(() {
          quantidadeAtual -= porcao / 1000;
          if (quantidadeAtual < 0) quantidadeAtual = 0;
        });
        await _salvarQuantidadeAtual();

        if (!porAutomacao) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ração liberada com sucesso!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!porAutomacao) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao liberar ração: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _registrarAbastecimento() {
    if (quantidadeAtual >= 5.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Capacidade máxima atingida (5.0 kg)!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double novaQuantidade = 0.5;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Registrar Abastecimento"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Quantidade adicionada (kg):"),
                  Slider(
                    value: novaQuantidade,
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    activeColor: Colors.deepPurple,
                    inactiveColor: Colors.deepPurple.withOpacity(0.3),
                    label: novaQuantidade.toStringAsFixed(1),
                    onChanged: (double value) {
                      setStateDialog(() {
                        if ((quantidadeAtual + value) <= 5.0) {
                          novaQuantidade = value;
                        } else {
                          novaQuantidade = 5.0 - quantidadeAtual;
                        }
                      });
                    },
                  ),
                  Text("${novaQuantidade.toStringAsFixed(1)} kg"),
                  if ((quantidadeAtual + novaQuantidade) >= 5.0)
                    Text(
                      "Capacidade máxima será atingida!",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(color: Colors.deepPurple[700]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      quantidadeAtual += novaQuantidade;
                      if (quantidadeAtual > 5.0) {
                        quantidadeAtual = 5.0;
                      }
                    });
                    await _salvarQuantidadeAtual();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Abastecimento registrado com sucesso!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[900],
                  ),
                  child: const Text("Confirmar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Alimentador Automático"),
        backgroundColor: Colors.deepPurple[900],
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple[900]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child:
                        user?.photoURL != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.network(
                                user!.photoURL!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => const Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.deepPurple,
                                    ),
                              ),
                            )
                            : Text(
                              user?.displayName?.isNotEmpty == true
                                  ? user!.displayName![0].toUpperCase()
                                  : "U",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.displayName ?? "Usuário",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    user?.email ?? "Não conectado",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Menu Principal"),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pets),
              title: const Text("Meus Pets"),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/pets');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Configurações"),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/configuracoes');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Sair"),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text("Sair"),
                        content: const Text(
                          "Tem certeza que deseja sair da sua conta?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Cancelar"),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              Navigator.of(context).pop();
                              Navigator.of(context).pushReplacementNamed('/');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text("Sair"),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple[900]!, Colors.deepPurple[200]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "MENU PRINCIPAL",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoCard("Próxima refeição em:", proximaRefeicao),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        "Qtnd Atual:",
                        "${quantidadeAtual.toStringAsFixed(2)} KG",
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        "Próximo Reabastecimento em:",
                        proximoReabastecimento,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/horarios');
                        },
                        icon: const Icon(Icons.access_time),
                        label: const Text("HORÁRIOS CADASTRADOS"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.deepPurple[800],
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _registrarAbastecimento,
                        icon: const Icon(Icons.add_box),
                        label: const Text("REGISTRAR ABASTECIMENTO"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (quantidadeAtual <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Quantidade já está em zero!"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            quantidadeAtual -= porcao / 1000;
                            if (quantidadeAtual < 0) quantidadeAtual = 0;
                          });
                          _salvarQuantidadeAtual();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Quantidade reduzida em ${porcao.toStringAsFixed(2)} kg",
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text("DIMINUIR QUANTIDADE"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _liberarRacao(porAutomacao: false),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("LIBERAR AGORA"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.orange[800],
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/bluetooth');
                        },
                        icon: const Icon(Icons.bluetooth),
                        label: const Text("CONECTAR VIA BLUETOOTH"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    final isUrgent = label.contains("Reabastecimento") && value == "0 dias";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUrgent ? Colors.red : Colors.deepPurple[200]!,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.deepPurple[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
