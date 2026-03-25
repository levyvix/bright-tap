# 🔦 Bright-Tap

Um daemon de controle automático de backlight de teclado para Linux (ThinkPad, Dell, HP, ASUS, etc).

## O que é?

**Bright-Tap** monitora a atividade do teclado e controla automaticamente o backlight (iluminação) de forma inteligente:

- ✨ **Acende** o backlight quando você digita
- 🌙 **Apaga** o backlight após 5 segundos de inatividade
- ⚡ **Funciona em background** como um daemon systemd
- 🎯 **Detecta múltiplos teclados** (suporta teclados externos também)
- 🚫 **Filtra dispositivos** (ignora touchpads, mouses, trackpoints)
- 💻 **Compatível com vários laptops** (auto-detecta backlight: ThinkPad, Dell, HP, ASUS, etc.)

## ⚡ Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/levyvix/bright-tap/main/install.sh | bash
```

> ℹ️ O script vai pedir sua senha (sudo) para instalar pacotes e criar o serviço

Pronto! O daemon já está rodando. 🎉

---

## Como funciona

```
[Teclado] → [Monitor asyncio] → [Timeout Handler] → [Controle de Backlight]
   ↓              ↓                    ↓
  evdev      Detecta pressionamento   /sys/class/leds/
             Reseta timer            tpacpi::kbd_backlight/
```

### Fluxo de execução

1. **Detecção de teclado**: O daemon encontra todos os dispositivos de entrada e filtra apenas teclados
2. **Monitoramento**: Aguarda eventos de tecla pressionada via `evdev`
3. **Ligação**: Ao detectar uma tecla, **acende o backlight** e inicia um timer de 5s
4. **Desligamento**: Se nenhuma tecla for pressionada nos 5s, **apaga o backlight**
5. **Reset**: Cada tecla pressionada durante os 5s reinicia o timer

### Requisitos

- Python 3.12+
- `python-evdev`
- Acesso a `/sys/class/leds/` (requer permissões root)
- Linux com backlight de teclado (ThinkPad, Dell, HP, ASUS, etc.)

## 💻 Compatibilidade de Laptops

O daemon **auto-detecta o backlight** do seu laptop. Funciona com:

| Marca | Modelos | Status |
|-------|---------|--------|
| **Lenovo ThinkPad** | X1, T-series, P-series, E-series | ✅ Testado |
| **Dell XPS, Inspiron** | Vários modelos | ✅ Suportado |
| **HP Pavilion, Envy** | Vários modelos | ✅ Suportado |
| **ASUS VivoBook, ROG** | Vários modelos | ✅ Suportado |
| **Outros** | Com `/sys/class/leds/` | ⚠️ Pode funcionar |

Se seu laptop não tiver backlight de teclado ou o daemon não encontrar o arquivo, o script informará no iniciar.

### Pré-requisitos

Instale o pacote `python-evdev` de acordo com sua distribuição Linux:

#### 🐧 Arch Linux / Manjaro / Endeavor OS
```bash
sudo pacman -S python-evdev
```

#### 🎩 Fedora / RHEL / CentOS / Rocky Linux
```bash
sudo dnf install python3-evdev
```

#### 🐋 Debian / Ubuntu / Linux Mint / Pop!_OS
```bash
sudo apt update
sudo apt install python3-evdev
```

#### 🦎 Alpine Linux
```bash
sudo apk add py3-evdev
```

#### 🦅 OpenSUSE / SUSE
```bash
sudo zypper install python3-evdev
```

#### 🔵 Void Linux
```bash
sudo xbps-install python3-evdev
```

#### 📦 Gentoo
```bash
sudo emerge dev-python/evdev
```

#### 🐮 Slackware
```bash
# Não disponível nos repositórios oficiais
# Use pip3 como fallback:
pip3 install --user evdev
```

#### 🔴 NixOS / Nix (flakes)
```bash
# Adicione ao seu shell.nix ou flake.nix
```

**Se sua distro não tiver o pacote:**
```bash
# Fallback para pip (menos recomendado)
pip3 install --user evdev
# ou
sudo pip3 install evdev
```

### Instalação rápida (uma linha)

**Instalação remota (recomendado para testes):**
```bash
curl -fsSL https://raw.githubusercontent.com/levyvix/bright-tap/main/install.sh | bash
```

**Instalação local:**
```bash
git clone https://github.com/levyvix/bright-tap.git
cd bright-tap
chmod +x install.sh
./install.sh
```

**O script vai:**
1. ✓ Detectar sua distribuição Linux automaticamente
2. ✓ Instalar `python-evdev` com o gerenciador correto
3. ✓ Copiar daemon para `/usr/local/bin/`
4. ✓ Criar serviço systemd
5. ✓ Ativar e iniciar o daemon

### Instalação manual

```bash
# Copiar daemon
sudo cp kbd-daemon.py /usr/local/bin/bright-tap-daemon
sudo chmod +x /usr/local/bin/bright-tap-daemon

# Criar arquivo de serviço
sudo tee /etc/systemd/system/bright-tap.service > /dev/null <<EOF
[Unit]
Description=Keyboard backlight daemon
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/bright-tap-daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Ativar e iniciar
sudo systemctl daemon-reload
sudo systemctl enable bright-tap
sudo systemctl start bright-tap
```

## Uso

### Verificar status

```bash
systemctl status bright-tap
```

### Ver logs

```bash
journalctl -u bright-tap -f
```

### Parar o daemon

```bash
sudo systemctl stop bright-tap
```

### Reiniciar

```bash
sudo systemctl restart bright-tap
```

## Estrutura do projeto

```
bright-tap/
├── kbd-daemon.py           # Daemon principal
├── kbd-daemon.service      # Arquivo de serviço systemd
├── main.py                 # CLI stub
├── install.sh              # Script de instalação
├── pyproject.toml          # Dependências Python
├── uv.lock                 # Lock de dependências
└── README.md               # Este arquivo
```

## Dependências

- **python-evdev**: Para monitorar eventos de teclado
  - Instalado via pacman: `sudo pacman -S python-evdev`
  - Não via pip (melhor usar o pacote do sistema)

## Arquitetura

### Componentes

| Componente | Função |
|-----------|--------|
| `find_keyboards()` | Detecta e filtra dispositivos de teclado |
| `monitor()` | Loop assíncrono que aguarda eventos de tecla |
| `timeout_handler()` | Gerencia o timer de desligamento do backlight |
| `set_light()` | Escreve no arquivo do sysfs para controlar backlight |

### Detalhes de implementação

- **Asyncio**: Usa `asyncio.Event()` e `asyncio.wait_for()` para gerenciar timers de forma eficiente
- **evdev**: Monitora `/dev/input/` para eventos de teclado
- **sysfs**: Controla backlight via `/sys/class/leds/tpacpi::kbd_backlight/brightness`

## Configuração

Para customizar o timeout (padrão: 5 segundos), edite `kbd-daemon.py`:

```python
TIMEOUT = 5  # Alterar para o valor desejado em segundos
```

## Troubleshooting

### "no keyboards found"

```bash
# Verificar dispositivos disponíveis
cat /proc/bus/input/devices

# Verificar permissões
ls -la /dev/input/
```

### Backlight não responde

```bash
# Verificar se o arquivo existe
ls -la /sys/class/leds/tpacpi::kbd_backlight/

# Testar manualmente
echo 1 | sudo tee /sys/class/leds/tpacpi::kbd_backlight/brightness  # Ligar
echo 0 | sudo tee /sys/class/leds/tpacpi::kbd_backlight/brightness  # Desligar
```

### Daemon não inicia

```bash
# Ver detalhes do erro
journalctl -u bright-tap -n 50
```

## Licença

MIT
