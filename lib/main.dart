import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

// Importações das páginas
import 'pages/login_page.dart';
import 'pages/menu_principal_page.dart';
import 'pages/busca_ble_page.dart';
import 'pages/configuracoes_page.dart';
import 'pages/CadastroHorarioPage.dart';
import 'pages/registro_page.dart';
import 'pages/globals.dart';

// Importação e criação da instância do UserData
import 'models/user_data.dart';

final userData = UserData();

void main() async {
  print("início do app");
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alimentador Automático',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/registro': (context) => RegistroPage(),
        '/home': (context) => MenuPrincipal(),
        '/bluetooth': (context) => BuscaBLEPage(),
        '/horarios': (context) => CadastroHorarioPage(),
        '/configuracoes': (context) => ConfiguracoesPage(esp32Ip: globalEsp32Ip!),

      },
    );
  }
}
