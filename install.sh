#!/bin/bash

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para printar com cor
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Verificar se estamos em um ThinkPad com backlight de teclado
check_hardware() {
    print_info "Verificando hardware..."

    if [ ! -f "/sys/class/leds/tpacpi::kbd_backlight/brightness" ]; then
        print_warning "Arquivo de backlight não encontrado"
        print_warning "Você pode não ter um ThinkPad com backlight de teclado"
        echo "Path esperado: /sys/class/leds/tpacpi::kbd_backlight/brightness"
        return 1
    fi

    print_success "Hardware detectado"
    return 0
}

# Obter o diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_SOURCE="$SCRIPT_DIR/kbd-daemon.py"
DAEMON_DEST="/usr/local/bin/bright-tap-daemon"
SERVICE_DEST="/etc/systemd/system/bright-tap.service"

print_info "Iniciando instalação do Bright-Tap"
echo

# Verificar se os arquivos existem
if [ ! -f "$DAEMON_SOURCE" ]; then
    print_error "Arquivo $DAEMON_SOURCE não encontrado"
    exit 1
fi

# Verificar hardware
if ! check_hardware; then
    print_warning "Continuando mesmo assim..."
fi
echo

# Verificar se python-evdev está instalado
print_info "Verificando dependências Python..."
if python3 -c "import evdev" 2>/dev/null; then
    print_success "python-evdev encontrado"
else
    print_warning "python-evdev não encontrado"
    echo
    print_info "Tentando instalar automaticamente..."

    # Detectar gerenciador de pacotes e instalar
    if command -v pacman &> /dev/null; then
        print_info "Detectado: Arch Linux/Manjaro"
        sudo pacman -S --noconfirm python-evdev
    elif command -v dnf &> /dev/null; then
        print_info "Detectado: Fedora/RHEL/CentOS"
        sudo dnf install -y python3-evdev
    elif command -v apt &> /dev/null; then
        print_info "Detectado: Debian/Ubuntu"
        sudo apt update
        sudo apt install -y python3-evdev
    elif command -v apk &> /dev/null; then
        print_info "Detectado: Alpine Linux"
        sudo apk add py3-evdev
    elif command -v zypper &> /dev/null; then
        print_info "Detectado: OpenSUSE/SUSE"
        sudo zypper install -y python3-evdev
    elif command -v xbps-install &> /dev/null; then
        print_info "Detectado: Void Linux"
        sudo xbps-install -y python3-evdev
    elif command -v emerge &> /dev/null; then
        print_info "Detectado: Gentoo"
        sudo emerge dev-python/evdev
    else
        print_error "Gerenciador de pacotes não identificado"
        echo
        print_info "Instale manualmente de acordo com sua distro:"
        echo "  Arch: sudo pacman -S python-evdev"
        echo "  Fedora: sudo dnf install python3-evdev"
        echo "  Debian/Ubuntu: sudo apt install python3-evdev"
        echo "  Alpine: sudo apk add py3-evdev"
        echo "  OpenSUSE: sudo zypper install python3-evdev"
        echo "  Void: sudo xbps-install python3-evdev"
        echo "  Gentoo: sudo emerge dev-python/evdev"
        echo "  Fallback: pip3 install --user evdev"
        echo
        exit 1
    fi

    # Verificar se instalação funcionou
    if ! python3 -c "import evdev" 2>/dev/null; then
        print_error "Falha ao instalar python-evdev"
        print_info "Tente instalar manualmente com pip:"
        echo "  pip3 install --user evdev"
        echo
        exit 1
    fi

    print_success "python-evdev instalado com sucesso"
fi
echo

# Obter o path do Python
PYTHON_PATH="python3"
print_info "Usando Python: $PYTHON_PATH"
echo

# Copiar daemon
print_info "Copiando daemon para $DAEMON_DEST..."
sudo cp "$DAEMON_SOURCE" "$DAEMON_DEST"
sudo chmod +x "$DAEMON_DEST"
print_success "Daemon instalado"
echo

# Criar arquivo de serviço com caminhos corretos
print_info "Criando arquivo de serviço systemd..."
sudo tee "$SERVICE_DEST" > /dev/null <<EOF
[Unit]
Description=Keyboard backlight daemon
After=multi-user.target

[Service]
Type=simple
ExecStart=$PYTHON_PATH $DAEMON_DEST
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
print_success "Arquivo de serviço criado"
echo

# Recarregar systemd
print_info "Recarregando systemd..."
sudo systemctl daemon-reload
print_success "Systemd recarregado"
echo

# Ativar o serviço
print_info "Ativando serviço bright-tap..."
sudo systemctl enable bright-tap
print_success "Serviço ativado"
echo

# Iniciar o daemon
print_info "Iniciando daemon..."
sudo systemctl start bright-tap
print_success "Daemon iniciado"
echo

# Verificar status
print_info "Verificando status do daemon..."
if systemctl is-active --quiet bright-tap; then
    print_success "Daemon rodando com sucesso!"
    echo
    systemctl status bright-tap --no-pager
else
    print_error "Falha ao iniciar daemon"
    echo "Use 'journalctl -u bright-tap -f' para ver mais detalhes"
    exit 1
fi

echo
print_success "Instalação completa!"
echo
echo "Próximos passos:"
echo "  • Ver status: systemctl status bright-tap"
echo "  • Ver logs: journalctl -u bright-tap -f"
echo "  • Parar daemon: sudo systemctl stop bright-tap"
echo "  • Reiniciar daemon: sudo systemctl restart bright-tap"
echo
echo "Para customizar o timeout, edite $DAEMON_DEST"
