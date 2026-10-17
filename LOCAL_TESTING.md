# AR Graffiti - Guia de Build e Testes em Celular Físico (Mesma Rede Wi-Fi)

Este documento orienta o passo a passo completo para executar o **Backend** no seu computador e fazer o **Build e Teste do App Mobile diretamente no seu Smartphone Android com ARCore**, ambos conectados na mesma rede Wi-Fi local.

---

## 📋 Pré-requisitos

1. **No Computador:**
   - Python 3.10+ instalado.
   - Flutter SDK 3.x e Android SDK instalados (`flutter doctor` sem erros críticos).
   - Computador e celular conectados na **mesma rede Wi-Fi**.
2. **No Celular Android:**
   - Sistema Android 7.0 (API 24) ou superior.
   - **Google Play Services para RA (ARCore):** Certifique-se de que está instalado e atualizado (pesquise por *"Serviços do Google Play para RA"* na Google Play Store).
   - **Depuração USB ativada:**
     - Vá em *Configurações > Sobre o telefone > Toque 7 vezes em "Número da versão"* para liberar o Modo Desenvolvedor.
     - Em *Opções do desenvolvedor*, ative a **Depuração USB**.

---

## 🌐 1. Descobrir o IP do seu Computador na Rede Local

Para o celular conseguir se comunicar com o backend rodando no seu computador:

1. No seu PC Windows, abra o PowerShell e execute:
   ```powershell
   ipconfig
   ```
2. Procure pelo adaptador **Wi-Fi** e anote o campo **Endereço IPv4** (exemplo: `192.168.1.15` ou `192.168.0.105`).

> ⚠️ **Importante (Firewall do Windows):**
> Se o celular não conseguir se comunicar com o PC, certifique-se de que a rede Wi-Fi está marcada como **Privada** no Windows, ou libere a porta 8000 no Firewall executando no PowerShell como Administrador:
> ```powershell
> New-NetFirewallRule -DisplayName "FastAPI AR Graffiti" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
> ```

---

## ⚙️ 2. Configurar o IP no Projeto Mobile

Abra o arquivo [`mobile/lib/core/config.dart`](mobile/lib/core/config.dart) e preencha o seu IP em `manualHostOverride`:

```dart
// mobile/lib/core/config.dart
class AppConfig {
  /// Substitua pelo IPv4 da sua máquina descoberto no passo anterior:
  static const String manualHostOverride = 'http://192.168.1.15:8000';
  ...
}
```
*Com isso, todas as requisições da API e os downloads das texturas de grafite para a câmera AR apontarão automaticamente para o backend no seu PC.*

---

## 💻 3. Iniciando o Backend (FastAPI + SQLite)

No terminal do seu computador:

```powershell
cd backend

# 1. Criar e ativar o ambiente virtual Python
python -m venv .venv
.venv\Scripts\activate

# 2. Instalar dependências
pip install -r requirements.txt

# 3. Iniciar o servidor ouvindo em 0.0.0.0 (obrigatorio para aceitar conexoes de outros aparelhos na rede)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

* **Teste no navegador do celular:** Abra o Chrome do celular e acesse `http://192.168.1.15:8000/health`. Se retornar `{"status":"ok",...}`, a comunicação entre o celular e o PC está funcionando perfeitamente!

---

## 📱 4. Gerando o Build e Instalando no Smartphone

Conecte o seu celular ao computador via cabo USB. No celular, autorize a caixa de diálogo *"Permitir depuração USB deste computador"*.

Abra outro terminal na pasta `mobile`:

```powershell
cd mobile

# 1. Baixar os pacotes
flutter pub get

# 2. Confirmar que o celular foi reconhecido
flutter devices
```
*Você verá o modelo do seu celular listado com um identificador.*

### Opção A: Executar diretamente no celular (com Hot Reload)
```powershell
flutter run
```
*(Se houver mais de um dispositivo listado, use `flutter run -d <ID_DO_DISPOSITIVO>`)*.

### Opção B: Gerar o arquivo APK para instalar manualmente
Se preferir gerar o pacote e enviar para o celular:
```powershell
flutter build apk --debug
```
* O APK gerado estará em: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
* Você pode copiá-lo para o celular e instalar diretamente.

---

## 🧪 5. Roteiro de Testes no Celular

### Teste 1: Permissões e Carregamento do Mapa
1. Abra o app no smartphone e conceda as permissões de **Câmera** e **Localização (GPS)** quando solicitadas.
2. O mapa OpenStreetMap será carregado centralizado na sua localização física real.

### Teste 2: Criar e Grafitar o Primeiro Ponto
1. Toque no botão rosa **"Grafitar Aqui"**.
2. Toque em **"Câmera"** para tirar uma foto na hora ou escolha uma foto/GIF da sua galeria.
3. Escolha o tipo de superfície (ex: *"Parede Vertical"*).
4. Toque em **"Grafitar e Proteger Ponto"**.
5. **Resultado:** O ponto é salvo no SQLite do PC, os uploads vão para `backend/uploads/` e no mapa surge o pino com **escudo dourado** (protegido por 24h).

### Teste 3: Projeção Real com ARCore na Parede
1. Estando próximo do local grafitado, toque no botão roxo **"Visão AR"**.
2. Aponte a câmera do celular para uma parede vertical ou superfície plana bem iluminada.
3. Mova o celular suavemente para os lados para o ARCore mapear o ambiente.
4. **Superfície Detectada:** Você verá uma malha de pontos sutis surgir na parede física.
5. **Fixando a Arte:** Toque em qualquer ponto da parede detectada na tela.
6. **Resultado de Imersão:**
   - O grafite é ancorado no ponto 3D exato da parede física.
   - **Ande para trás:** O grafite diminui em perspectiva realista.
   - **Aproxime-se:** O grafite amplia com nitidez.
   - **Ande de lado:** O grafite acompanha o ângulo da parede real.
   - **Aponte para longe e volte:** O grafite permanece cravado exatamente onde você o fixou.

### Teste 4: Regra King of the Hill (10 Metros)
1. Sem sair do local, tente abrir novamente o menu **"Grafitar Aqui"** e enviar outra imagem.
2. **Resultado:** O app exibe mensagem de bloqueio informando que o ponto está sob proteção de 24h.
