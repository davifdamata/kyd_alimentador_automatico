import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_data.dart'; // Importe o arquivo onde UserData está definido
import 'package:http/http.dart' as http;


class ConfiguracoesPage extends StatefulWidget {
  final String esp32Ip;

  const ConfiguracoesPage({super.key, required this.esp32Ip});
  @override
  _ConfiguracoesPageState createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Configurações"),
      backgroundColor: Colors.deepPurple[900],
      elevation: 0,
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurple[800]!, Colors.deepPurple[200]!],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingsSection("Conta e Perfil", [
                _buildProfileCard(),
                const SizedBox(height: 10),
                _buildSettingsCard("Alterar senha", Icons.lock_outline, () {
                  _showChangePasswordDialog();
                }),
                _buildSettingsCard("Editar perfil", Icons.edit, () {
                  _showEditProfileDialog();
                }),
                _buildSettingsCard(
                  "Gerenciar conta",
                  Icons.account_circle_outlined,
                  () {
                    _showManageAccountDialog();
                  },
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => resetarRedeESP32(context, widget.esp32Ip),
                  icon: const Icon(Icons.wifi_off),
                  label: const Text("ESQUECER REDE DO ESP32"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
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
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context)
                                  .pushReplacementNamed('/');
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "SAIR DA CONTA",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


  Widget _buildProfileCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.deepPurple[100],
              child: UserData.photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.network(
                        UserData.photoUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, size: 40),
                      ),
                    )
                  : Text(
                      UserData.nome.isNotEmpty
                          ? UserData.nome[0].toUpperCase()
                          : "U",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    UserData.nome,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    UserData.email,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple[900],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepPurple[700], size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final _senhaAtualController = TextEditingController();
    final _novaSenhaController = TextEditingController();
    final _confirmaSenhaController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Alterar Senha"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _senhaAtualController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Senha atual",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Digite sua senha atual";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _novaSenhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Nova senha",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Digite a nova senha";
                  }
                  if (value.length < 6) {
                    return "A senha deve ter pelo menos 6 caracteres";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmaSenhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirme a nova senha",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Confirme a nova senha";
                  }
                  if (value != _novaSenhaController.text) {
                    return "As senhas não coincidem";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final user = _auth.currentUser;
                if (user != null) {
                  try {
                    // Verifica a senha atual
                    final credencial = EmailAuthProvider.credential(
                      email: user.email!,
                      password: _senhaAtualController.text,
                    );
                    await user.reauthenticateWithCredential(credencial);

                    // Atualiza a senha
                    await user.updatePassword(_novaSenhaController.text);

                    // Fecha o diálogo e exibe mensagem de sucesso
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Senha alterada com sucesso!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    // Exibe mensagem de erro
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Erro: ${e.message}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text("Alterar"),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final _nomeController = TextEditingController(text: UserData.nome);
    final _emailController = TextEditingController(text: UserData.email);
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Perfil"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: "Nome",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Digite seu nome";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "E-mail",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Digite seu e-mail";
                  }
                  if (!value.contains("@")) {
                    return "E-mail inválido";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final user = _auth.currentUser;
                if (user != null) {
                  try {
                    // Atualiza o e-mail no Firebase Auth
                    await user.updateEmail(_emailController.text);

                    // Atualiza o nome no Firestore
                    await _firestore
                        .collection('users')
                        .doc(user.uid)
                        .update({'nome': _nomeController.text});

                    // Atualiza os dados locais
                    setState(() {
                      UserData.nome = _nomeController.text;
                      UserData.email = _emailController.text;
                    });

                    // Fecha o diálogo e exibe mensagem de sucesso
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Perfil atualizado com sucesso!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    // Exibe mensagem de erro
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Erro: ${e.message}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  void resetarRedeESP32(BuildContext context, String esp32Ip) async {
  try {
    final response = await http.post(Uri.parse("http://$esp32Ip/reset"));
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rede Wi-Fi do ESP32 esquecida. Reinicie o dispositivo."),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao resetar: ${response.statusCode}"),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erro: $e")),
    );
  }
}


  void _showManageAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Gerenciar Conta"),
        content: const Text(
          "Escolha uma opção para gerenciar sua conta.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user != null) {
                try {
                  // Exclui a conta do Firebase Auth
                  await user.delete();

                  // Exclui os dados do Firestore
                  await _firestore.collection('users').doc(user.uid).delete();

                  // Fecha o diálogo e redireciona para a tela de login
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/');
                } on FirebaseAuthException catch (e) {
                  // Exibe mensagem de erro
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erro: ${e.message}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Excluir Conta"),
          ),
        ],
      ),
    );
  }
}