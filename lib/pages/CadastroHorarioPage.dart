import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CadastroHorarioPage extends StatefulWidget {
  const CadastroHorarioPage({super.key});

  @override
  State<CadastroHorarioPage> createState() => _CadastroHorarioPageState();
}

class _CadastroHorarioPageState extends State<CadastroHorarioPage> {
  final List<TimeOfDay?> horarios = [null, null, null];
  final TextEditingController porcaoController = TextEditingController();
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosExistentes();
  }

  Future<void> _carregarDadosExistentes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('horarios_alimentacao')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final dados = doc.data()!;
      final porcao = dados['porcao'];
      final horariosSalvos = List<String>.from(dados['horarios']);

      porcaoController.text = porcao.toString();

      for (int i = 0; i < horariosSalvos.length && i < 3; i++) {
        final partes = horariosSalvos[i].split(":");
        final hora = int.parse(partes[0]);
        final minuto = int.parse(partes[1]);
        horarios[i] = TimeOfDay(hour: hora, minute: minuto);
      }
    }

    setState(() {
      carregando = false;
    });
  }

  Future<void> _salvarDados() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final porcao = porcaoController.text.trim();
    if (porcao.isEmpty || horarios.every((h) => h == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha pelo menos um horário e a porção.")),
      );
      return;
    }

    final porcaoDouble = double.tryParse(porcao);
    if (porcaoDouble == null || porcaoDouble <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Porção inválida.")),
      );
      return;
    }

    final List<String> horariosFormatados = horarios
        .where((h) => h != null)
        .map((h) => h!.format(context))
        .toList();

    try {
      await FirebaseFirestore.instance
          .collection('horarios_alimentacao')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'porcao': porcaoDouble,
        'horarios': horariosFormatados,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Horários e porção salvos com sucesso!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selecionarHorario(int index) async {
    final TimeOfDay? escolhido = await showTimePicker(
      context: context,
      initialTime: horarios[index] ?? TimeOfDay.now(),
    );

    if (escolhido != null) {
      setState(() => horarios[index] = escolhido);
    }
  }

  @override
  void dispose() {
    porcaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cadastrar / Editar Horários"),
        backgroundColor: Colors.deepPurple[800],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: porcaoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Porção (g)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          horarios[i] == null
                              ? "Selecionar Horário ${i + 1}"
                              : "Horário ${i + 1}: ${horarios[i]!.format(context)}",
                        ),
                        onPressed: () => _selecionarHorario(i),
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _salvarDados,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    ),
                    child: const Text("Salvar", style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }
}
