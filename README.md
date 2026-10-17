# AR Graffiti - MVP (SQLite + FastAPI & Flutter)

Projeto MVP de jogo colaborativo de grafite virtual em Realidade Aumentada (AR) e mapas do mundo real com mecânica territorial *King of the Hill*.

---

## 🚀 Como Executar o Backend (FastAPI + SQLite)

O backend é 100% autossuficiente e utiliza **SQLite** e armazenamento local de arquivos, não dependendo de nenhum serviço externo ou banco PostgreSQL instalado.

### 1. Pré-requisitos
* Python 3.10+ instalado.

### 2. Instalação e Execução
Na pasta raiz do projeto:

```bash
cd backend

# Criar ambiente virtual (opcional, recomendado)
python -m venv .venv
# No Windows:
.venv\Scripts\activate
# No Linux/Mac:
source .venv/bin/activate

# Instalar dependências
pip install -r requirements.txt

# Iniciar o servidor FastAPI com recarregamento automático
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

* **Swagger / Documentação Interativa:** Acesse [http://localhost:8000/docs](http://localhost:8000/docs)
* **Verificação de Saúde:** Acesse [http://localhost:8000/health](http://localhost:8000/health)
* **Banco de Dados:** O arquivo `graffiti.db` será criado automaticamente na pasta `backend/`.
* **Uploads de Mídia:** Salvos localmente em `backend/uploads/` e servidos em `/static/uploads/`.

---

## 📱 Como Executar o App Mobile (Flutter)

### 1. Pré-requisitos
* Flutter SDK 3.x instalado e configurado (`flutter doctor`).
* Emulador Android, Simulador iOS ou aparelho físico conectado via USB/Wi-Fi.

### 2. Configuração de Rede
Se estiver testando em um **aparelho físico**, abra o arquivo [`mobile/lib/core/config.dart`](mobile/lib/core/config.dart) e aponte o IP para o da sua máquina na rede local:
```dart
// Exemplo para celular físico na mesma Wi-Fi:
return 'http://192.168.1.100:8000/api/v1';
```
*(Para o emulador Android padrão, a rota `http://10.0.2.2:8000/api/v1` já está configurada automaticamente).*

### 3. Execução
```bash
cd mobile

# Obter dependências do Flutter
flutter pub get

# Executar no dispositivo conectado
flutter run
```

> 📖 **Guia Passo a Passo para Smartphone Físico:** Consulte o arquivo [`LOCAL_TESTING.md`](LOCAL_TESTING.md) para instruções detalhadas de configuração de IP da rede local Wi-Fi, liberação de portas e roteiro de testes práticos com ARCore.


---

## 🎮 Mecânicas do Jogo Implementadas no MVP

1. **Raio de 10 Metros (Exclusividade):** O mapa e o banco de dados calculam a distância métrica por fórmula de Haversine. Só pode haver 1 arte ativa no raio de 10 metros.
2. **Proteção de 24 Horas:** Quando um usuário pinta um ponto, a arte fica imune contra sobrescritas por 24h.
3. **King of the Hill:** Após 24h e até 7 dias, qualquer jogador no local físico pode "cobrir" a arte antiga e reivindicar o ponto.
4. **Validade de 7 Dias:** Grafites expiram automaticamente se não forem renovados.
5. **Realidade Aumentada (AR):** Detecção de planos de paredes e pisos com fixação das artes 2D na câmera.
6. **Moderação Automática:** Grafites com 3 denúncias são ocultados automaticamente da exibição pública.
