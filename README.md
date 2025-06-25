# KYD – Alimentador Automático 🐾  
Trabalho de Conclusão de Curso (Técnico em Informática – ETEC)

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Projeto de IoT que integra **ESP32**, **Flutter** e **Firebase** para dispensar ração de forma automática ou manual, com controle total via aplicativo.

---

## ✨ Visão Geral
- **Automatiza** horários de alimentação de pets.  
- **App Flutter** para cadastro de horários, porções e monitoramento em tempo real.  
- **ESP32** recebe as configurações via Bluetooth, conecta-se ao Wi-Fi e aciona o motor que libera a ração.  
- Protótipo físico construído em **PVC** + motor de passo.

---

## 🗂️ Estrutura do Repositório
```text
.
├── lib/        # Código do aplicativo
├── esp32_firmware/     # Firmware para a placa ESP32
├── hardware/           # Fotos, diagrama e lista de materiais
└── README.md           # Este arquivo
```

---

## 📱 Aplicativo Flutter
| Tela | Descrição |
|------|-----------|
| **Menu Principal** | Contagem regressiva até a próxima refeição + botão “Liberar agora” |
| **Horários**  | Cadastrar/editar horários e porções |
| **Configurar Wi-Fi** | Escolha da rede e envio de senha via BLE |
| **Alertas** | Aviso de reabastecimento ou falha |

**Principais pacotes**  
`flutter_blue_plus · firebase_core · cloud_firestore · riverpod`

---

## 🔌 Firmware ESP32
- **Linguagem:** C++ (Arduino IDE)  
- **Tarefas principais:**  
  1. Receber credenciais e horários por BLE  
  2. Conectar-se ao Wi-Fi e sincronizar hora (NTP)  
  3. Acionar motor de passo na hora programada  
  4. Enviar status/alertas ao Firebase  
- **Pins sugeridos:** DIR = D2 · STEP = D4 · EN = D5 (ajuste em `config.h`)

---

## 🛠️ Hardware (protótipo PVC)
| Peça | Qtd | Observação |
|------|-----|------------|
| Cano PVC 100 mm | 60 cm | Corpo do reservatório |
| Motor de passo 28BYJ-48 + ULN2003 | 1 | Dosagem precisa |
| ESP32 DevKit V1 | 1 | Microcontrolador |
| Fonte 5 V 2 A | 1 | Alimentação |
| Parafusos, tampas, cola PVC | — | Montagem |

Fotos e guia de montagem em `/hardware/`.

---

## 🚀 Como Rodar

### 1. Clonar o projeto
```bash
git clone https://github.com/davifdamata/kyd_alimentador_automatico.git
cd kyd_alimentador_automatico
```

### 2. App Flutter
```bash
cd app_flutter
flutter pub get
flutter run   # selecione emulador ou dispositivo físico
```

### 3. Firmware ESP32
1. Abra `esp32_firmware/esp32_alimentador.ino` no Arduino IDE.  
2. Instale o pacote da placa **ESP32** (Boards Manager).  
3. Ajuste `config.h` se necessário.  
4. Compile e faça o upload para a placa.

---

## 🌐 Configuração Firebase (opcional)
1. Criar projeto no Firebase.  
2. Ativar Firestore.  
3. Baixar `google-services.json` (Android) e/ou `GoogleService-Info.plist` (iOS)  
   e colocar nas pastas correspondentes em `app_flutter/`.  
4. Atualizar chaves de API, se preciso.

---

## ▶️ Demonstração
- **Vídeo:** `/hardware/demo.mp4` (protótipo em ação)  
- **Prints:** `/app_flutter/screenshots/`

---

## 📅 Roadmap
- Atualização OTA via Wi-Fi  
- Modo multi-pet  
- Enclosure definitivo impresso em 3D  
- CI/CD com GitHub Actions

---

## 👥 Autor & Agradecimentos
| Função | Responsável |
|--------|-------------|
| Desenvolvimento do app e firmware | **Davi Mata** |
| Montagem física, testes, documentação | Equipe KYD |
| Orientação técnica | Prof. **Victor Vicaria** |

---

## 📄 Licença
Distribuído sob a licença MIT. Consulte o arquivo `LICENSE` para mais detalhes.
