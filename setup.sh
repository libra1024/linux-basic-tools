#!/bin/bash

# =============================================================================
#  Setup Dev Environment
#  Detecta el OS (Debian/Ubuntu, Fedora, Arch) e instala herramientas de dev
#
#  Orden de instalación:
#    1.  Detectar OS
#    2.  Actualizar sistema + dependencias base (+ yay en Arch)
#    3.  Zsh + Oh My Zsh (todo lo demás se configura sobre Zsh)
#    4.  Homebrew
#    5.  BellSoft Liberica JDK 21
#    6.  net-tools
#    7.  VS Code
#    8.  VS Code Insiders
#    9.  macchanger
#   10.  build-essential / GCC
#   11.  jEnv
#   12.  pyenv
#   13.  JetBrains Toolbox
#   14.  DBeaver CE
#   15.  Docker Engine + Compose
#   16.  Docker Desktop
#   17.  PeaZip (GTK2)
#   18.  Firefox
#   19.  Brave Browser
#   20.  Fastfetch
# =============================================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Variables globales ───────────────────────────────────────────────────────
DISTRO=""
OS_ID=""
PKG_MANAGER=""
FAILED=()
TOTAL_STEPS=20
ARCH_HW=$(uname -m)
ARCH_PKG=""

case "$ARCH_HW" in
    x86_64)  ARCH_PKG="amd64" ;;
    aarch64) ARCH_PKG="arm64" ;;
    *)       ARCH_PKG="$ARCH_HW" ;;
esac

# ── Funciones de utilidad ────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
ok()      { echo -e "${GREEN}[  OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
fail()    { echo -e "${RED}[FAIL]${NC}    $1"; }
step()    {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

run_install() {
    local nombre="$1"
    shift
    info "Instalando ${nombre}..."
    if "$@" >/dev/null 2>&1; then
        ok "${nombre} instalado correctamente."
    else
        fail "No se pudo instalar ${nombre}."
        FAILED+=("$nombre")
    fi
}

command_exists() { command -v "$1" &>/dev/null; }

# Instalar paquete(s) con yay como usuario normal (Arch)
yay_install() {
    local nombre="$1"
    shift
    info "Instalando ${nombre} (yay)..."
    if sudo -u "$REAL_USER" yay -S --noconfirm --needed "$@" >/dev/null 2>&1; then
        ok "${nombre} instalado correctamente."
    else
        fail "No se pudo instalar ${nombre}."
        FAILED+=("$nombre")
    fi
}

# Escribe un bloque en .zshrc evitando duplicados
add_to_zshrc() {
    local marker="$1"
    local content="$2"
    local target="${REAL_HOME}/.zshrc"

    if [[ -f "$target" ]] && grep -qF "$marker" "$target" 2>/dev/null; then
        warn "Configuración '${marker}' ya existe en .zshrc"
        return 0
    fi

    {
        echo ""
        echo "# ── ${marker} ──"
        echo -e "$content"
    } >> "$target"

    chown "${REAL_USER}:${REAL_USER}" "$target"
    ok "'${marker}' agregado a .zshrc"
}

# ── Verificar root ───────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Este script debe ejecutarse como root (sudo).${NC}"
    echo "Uso: sudo bash setup-dev-env.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${REAL_USER}")

# =============================================================================
#  1. DETECCIÓN DEL SISTEMA OPERATIVO
# =============================================================================
step "1/${TOTAL_STEPS} ─ Detectando sistema operativo"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_ID="${ID,,}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_ID_LIKE="${OS_ID_LIKE,,}"
    OS_PRETTY="${PRETTY_NAME}"
else
    fail "No se encontró /etc/os-release. Sistema no soportado."
    exit 1
fi

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_ID_LIKE" == *"debian"* || "$OS_ID_LIKE" == *"ubuntu"* ]]; then
    DISTRO="debian"
    PKG_MANAGER="apt"

elif [[ "$OS_ID" == "fedora" || "$OS_ID_LIKE" == *"fedora"* ]]; then
    DISTRO="fedora"
    PKG_MANAGER="dnf"

elif [[ "$OS_ID" == "arch" || "$OS_ID" == "manjaro" || "$OS_ID_LIKE" == *"arch"* ]]; then
    DISTRO="arch"
    PKG_MANAGER="pacman + yay"

else
    fail "Distribución '${OS_PRETTY}' no soportada."
    echo -e "${YELLOW}Soportadas: Debian/Ubuntu, Fedora, Arch/Manjaro.${NC}"
    exit 1
fi

ok "Sistema detectado: ${OS_PRETTY}"
info "Familia: ${DISTRO} | Gestor: ${PKG_MANAGER} | Arch: ${ARCH_HW} (${ARCH_PKG})"

# =============================================================================
#  2. ACTUALIZAR SISTEMA + DEPENDENCIAS BASE  (+ yay en Arch)
# =============================================================================
step "2/${TOTAL_STEPS} ─ Actualizando sistema e instalando dependencias base"

info "Actualizando repositorios y paquetes..."
case "$DISTRO" in
    debian) apt update && apt upgrade -y ;;
    fedora) dnf upgrade -y ;;
    arch)   pacman -Syu --noconfirm ;;
esac
ok "Sistema actualizado."

info "Instalando dependencias base..."
case "$DISTRO" in
    debian)
        apt install -y curl wget gnupg2 ca-certificates lsb-release \
            apt-transport-https software-properties-common git \
            fontconfig unzip >/dev/null 2>&1
        ;;
    fedora)
        dnf install -y curl wget gnupg2 ca-certificates git \
            fontconfig unzip util-linux-user >/dev/null 2>&1
        ;;
    arch)
        pacman -S --needed --noconfirm curl wget ca-certificates git \
            fontconfig unzip base-devel >/dev/null 2>&1
        ;;
esac
ok "Dependencias base instaladas."

# ── Instalar yay en Arch (necesario para todo lo demás) ──
if [[ "$DISTRO" == "arch" ]]; then
    if command_exists yay; then
        warn "yay ya está instalado."
    else
        info "Instalando yay desde AUR..."
        sudo -u "$REAL_USER" bash -c '
            cd /tmp && rm -rf yay
            git clone https://aur.archlinux.org/yay.git
            cd yay && makepkg -si --noconfirm
        ' && ok "yay instalado correctamente." || {
            fail "No se pudo instalar yay. Las instalaciones de Arch dependen de él."
            FAILED+=("yay")
        }
    fi
fi

# =============================================================================
#  3. ZSH + OH MY ZSH  (primero — todo lo demás se configura aquí)
# =============================================================================
step "3/${TOTAL_STEPS} ─ Instalando Zsh + Oh My Zsh"

if command_exists zsh; then
    warn "Zsh ya está instalado: $(zsh --version)"
else
    case "$DISTRO" in
        debian) run_install "Zsh" apt install -y zsh ;;
        fedora) run_install "Zsh" dnf install -y zsh ;;
        arch)   yay_install "Zsh" zsh ;;
    esac
fi

# Shell por defecto
ZSH_PATH=$(which zsh 2>/dev/null || echo "/usr/bin/zsh")
CURRENT_SHELL=$(getent passwd "$REAL_USER" | cut -d: -f7)
if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
    info "Cambiando shell de '${REAL_USER}' a Zsh..."
    chsh -s "$ZSH_PATH" "$REAL_USER" 2>/dev/null && \
        ok "Zsh es ahora el shell por defecto." || \
        warn "No se pudo cambiar el shell. Ejecuta: chsh -s ${ZSH_PATH}"
else
    ok "Zsh ya es el shell por defecto."
fi

[[ ! -f "${REAL_HOME}/.zshrc" ]] && sudo -u "$REAL_USER" touch "${REAL_HOME}/.zshrc"

# Oh My Zsh
if [[ -d "${REAL_HOME}/.oh-my-zsh" ]]; then
    warn "Oh My Zsh ya está instalado."
else
    info "Instalando Oh My Zsh..."
    sudo -u "$REAL_USER" bash -c \
        'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' && \
        ok "Oh My Zsh instalado." || { warn "Oh My Zsh falló."; FAILED+=("Oh My Zsh"); }
fi

# Plugins
info "Instalando plugins de Zsh..."
ZSH_CUSTOM="${REAL_HOME}/.oh-my-zsh/custom"
if [[ -d "$ZSH_CUSTOM" ]]; then
    [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]] && \
        sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-autosuggestions \
            "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" 2>/dev/null && \
            ok "zsh-autosuggestions instalado." || true

    [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]] && \
        sudo -u "$REAL_USER" git clone https://github.com/zsh-users/zsh-syntax-highlighting \
            "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" 2>/dev/null && \
            ok "zsh-syntax-highlighting instalado." || true

    if grep -q "^plugins=(" "${REAL_HOME}/.zshrc" 2>/dev/null; then
        sed -i 's/^plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker docker-compose)/' \
            "${REAL_HOME}/.zshrc"
        ok "Plugins activados en .zshrc"
    fi
fi

ok "Zsh completamente configurado."

# =============================================================================
#  4. HOMEBREW (Linuxbrew)
# =============================================================================
step "4/${TOTAL_STEPS} ─ Instalando Homebrew (Linuxbrew)"

if command_exists brew || sudo -u "$REAL_USER" bash -c 'command -v brew' &>/dev/null; then
    warn "Homebrew ya está instalado."
else
    info "Instalando Homebrew como usuario '${REAL_USER}'..."
    sudo -u "$REAL_USER" bash -c \
        'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' && {

        BREW_PREFIX="/home/linuxbrew/.linuxbrew"
        [[ ! -d "$BREW_PREFIX" ]] && BREW_PREFIX="/opt/homebrew"

        if [[ -d "$BREW_PREFIX" ]]; then
            add_to_zshrc "Homebrew" "eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""
            eval "$("${BREW_PREFIX}/bin/brew" shellenv)" 2>/dev/null || true
        fi
        ok "Homebrew instalado."
    } || {
        fail "No se pudo instalar Homebrew."
        FAILED+=("Homebrew")
    }
fi

# =============================================================================
#  5. BellSoft Liberica JDK 21
# =============================================================================
step "5/${TOTAL_STEPS} ─ Instalando BellSoft Liberica JDK 21"

JAVA_HOME_PATH=""

case "$DISTRO" in
    debian)
        install -m 0755 -d /etc/apt/keyrings
        wget -qO - https://download.bell-sw.com/pki/GPG-KEY-bellsoft \
            | gpg --dearmor -o /etc/apt/keyrings/bellsoft.gpg 2>/dev/null || true
        echo "deb [signed-by=/etc/apt/keyrings/bellsoft.gpg] https://apt.bell-sw.com/ stable main" \
            > /etc/apt/sources.list.d/bellsoft.list
        apt update >/dev/null 2>&1
        run_install "BellSoft JDK 21" apt install -y bellsoft-java21-full
        ;;
    fedora)
        cat > /etc/yum.repos.d/bellsoft.repo <<'EOF'
[BellSoft]
name=BellSoft Repository
baseurl=https://yum.bell-sw.com
enabled=1
gpgcheck=1
gpgkey=https://download.bell-sw.com/pki/GPG-KEY-bellsoft
EOF
        run_install "BellSoft JDK 21" dnf install -y bellsoft-java21-full
        ;;
    arch)
        yay_install "BellSoft JDK 21" bellsoft-java21
        ;;
esac

JAVA_HOME_PATH=$(find /usr/lib/jvm -maxdepth 1 -type d \( -name "*bellsoft*" -o -name "*liberica*" \) 2>/dev/null | head -1)
if [[ -n "$JAVA_HOME_PATH" ]]; then
    add_to_zshrc "JAVA_HOME" "export JAVA_HOME=\"${JAVA_HOME_PATH}\"\nexport PATH=\"\$JAVA_HOME/bin:\$PATH\""
fi

# =============================================================================
#  6. NET-TOOLS
# =============================================================================
step "6/${TOTAL_STEPS} ─ Instalando net-tools"

case "$DISTRO" in
    debian) run_install "net-tools" apt install -y net-tools ;;
    fedora) run_install "net-tools" dnf install -y net-tools ;;
    arch)   yay_install "net-tools" net-tools ;;
esac

# =============================================================================
#  7. VISUAL STUDIO CODE
# =============================================================================
step "7/${TOTAL_STEPS} ─ Instalando Visual Studio Code"

if command_exists code; then
    warn "VS Code ya está instalado: $(code --version 2>/dev/null | head -1)"
else
    case "$DISTRO" in
        debian)
            install -m 0755 -d /etc/apt/keyrings
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
                | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg 2>/dev/null || true
            echo "deb [arch=${ARCH_PKG} signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
                > /etc/apt/sources.list.d/vscode.list
            apt update >/dev/null 2>&1
            run_install "VS Code" apt install -y code
            ;;
        fedora)
            rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
            cat > /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
            run_install "VS Code" dnf install -y code
            ;;
        arch)
            yay_install "VS Code" visual-studio-code-bin
            ;;
    esac
fi

# =============================================================================
#  8. VISUAL STUDIO CODE INSIDERS
# =============================================================================
step "8/${TOTAL_STEPS} ─ Instalando Visual Studio Code Insiders"

if command_exists code-insiders; then
    warn "VS Code Insiders ya está instalado."
else
    case "$DISTRO" in
        debian) run_install "VS Code Insiders" apt install -y code-insiders ;;
        fedora) run_install "VS Code Insiders" dnf install -y code-insiders ;;
        arch)   yay_install "VS Code Insiders" visual-studio-code-insiders-bin ;;
    esac
fi

# =============================================================================
#  9. MACCHANGER
# =============================================================================
step "9/${TOTAL_STEPS} ─ Instalando macchanger"

if command_exists macchanger; then
    warn "macchanger ya está instalado."
else
    case "$DISTRO" in
        debian) DEBIAN_FRONTEND=noninteractive run_install "macchanger" apt install -y macchanger ;;
        fedora) run_install "macchanger" dnf install -y macchanger ;;
        arch)   yay_install "macchanger" macchanger ;;
    esac
fi

# =============================================================================
#  10. BUILD-ESSENTIAL / GCC
# =============================================================================
step "10/${TOTAL_STEPS} ─ Instalando herramientas de compilación"

case "$DISTRO" in
    debian)
        run_install "build-essential" apt install -y build-essential
        ;;
    fedora)
        info "Instalando grupo 'Development Tools'..."
        dnf groupinstall -y "Development Tools" >/dev/null 2>&1 && \
            ok "Development Tools instalado." || { fail "Development Tools falló."; FAILED+=("Development Tools"); }
        run_install "gcc / gcc-c++ / make" dnf install -y gcc gcc-c++ make
        ;;
    arch)
        yay_install "base-devel" base-devel
        ;;
esac

# =============================================================================
#  11. JENV
# =============================================================================
step "11/${TOTAL_STEPS} ─ Instalando jEnv"

if [[ -d "${REAL_HOME}/.jenv" ]]; then
    warn "jEnv ya está instalado."
else
    info "Clonando jEnv..."
    sudo -u "$REAL_USER" git clone https://github.com/jenv/jenv.git \
        "${REAL_HOME}/.jenv" 2>/dev/null && {

        add_to_zshrc "jEnv" 'export PATH="$HOME/.jenv/bin:$PATH"\neval "$(jenv init -)"'
        ok "jEnv instalado."
    } || {
        fail "No se pudo instalar jEnv."
        FAILED+=("jEnv")
    }
fi

if [[ -d "${REAL_HOME}/.jenv" && -n "${JAVA_HOME_PATH:-}" ]]; then
    info "Registrando BellSoft JDK 21 en jEnv..."
    sudo -u "$REAL_USER" bash -c "
        export PATH=\"\$HOME/.jenv/bin:\$PATH\"
        eval \"\$(jenv init -)\"
        jenv add \"${JAVA_HOME_PATH}\" 2>/dev/null
    " && ok "JDK registrado en jEnv." || warn "Registra el JDK manualmente: jenv add <ruta>"
fi

# =============================================================================
#  12. PYENV
# =============================================================================
step "12/${TOTAL_STEPS} ─ Instalando pyenv"

if [[ -d "${REAL_HOME}/.pyenv" ]]; then
    warn "pyenv ya está instalado."
else
    info "Instalando dependencias de compilación de Python..."
    case "$DISTRO" in
        debian)
            apt install -y make build-essential libssl-dev zlib1g-dev \
                libbz2-dev libreadline-dev libsqlite3-dev llvm \
                libncursesw5-dev xz-utils tk-dev libxml2-dev \
                libxmlsec1-dev libffi-dev liblzma-dev >/dev/null 2>&1
            ;;
        fedora)
            dnf install -y gcc make zlib-devel bzip2-devel readline-devel \
                sqlite-devel openssl-devel tk-devel libffi-devel \
                xz-devel libuuid-devel gdbm-devel libnsl2-devel >/dev/null 2>&1
            ;;
        arch)
            sudo -u "$REAL_USER" yay -S --needed --noconfirm base-devel openssl zlib \
                xz tk sqlite ncurses >/dev/null 2>&1
            ;;
    esac

    info "Instalando pyenv..."
    sudo -u "$REAL_USER" bash -c \
        'curl -fsSL https://pyenv.run | bash' && {

        add_to_zshrc "pyenv" 'export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"'

        ok "pyenv instalado."
    } || {
        fail "No se pudo instalar pyenv."
        FAILED+=("pyenv")
    }
fi

# =============================================================================
#  13. JETBRAINS TOOLBOX
# =============================================================================
step "13/${TOTAL_STEPS} ─ Instalando JetBrains Toolbox"

if [[ -f "/opt/jetbrains-toolbox/jetbrains-toolbox" ]] || command_exists jetbrains-toolbox; then
    warn "JetBrains Toolbox ya está instalado."
else
    case "$DISTRO" in
        arch)
            yay_install "JetBrains Toolbox" jetbrains-toolbox
            ;;
        *)
            info "Obteniendo URL de descarga..."
            JB_URL=$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" \
                | grep -oP '"linux":\{[^}]*"link":"\K[^"]+' | head -1) || true

            if [[ -n "${JB_URL:-}" ]]; then
                info "Descargando JetBrains Toolbox..."
                wget -qO /tmp/jetbrains-toolbox.tar.gz "$JB_URL" && {
                    mkdir -p /opt/jetbrains-toolbox
                    tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
                    chmod +x /opt/jetbrains-toolbox/jetbrains-toolbox
                    ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox
                    rm -f /tmp/jetbrains-toolbox.tar.gz
                    ok "JetBrains Toolbox instalado en /opt/jetbrains-toolbox/"
                } || {
                    fail "Descarga de JetBrains Toolbox falló."
                    FAILED+=("JetBrains Toolbox")
                }
            else
                fail "No se pudo obtener la URL de JetBrains Toolbox."
                FAILED+=("JetBrains Toolbox")
            fi
            ;;
    esac
fi

# =============================================================================
#  14. DBEAVER Community Edition
# =============================================================================
step "14/${TOTAL_STEPS} ─ Instalando DBeaver Community Edition"

if command_exists dbeaver || command_exists dbeaver-ce; then
    warn "DBeaver ya está instalado."
else
    case "$DISTRO" in
        debian)
            info "Descargando DBeaver .deb..."
            wget -qO /tmp/dbeaver.deb "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" && {
                dpkg -i /tmp/dbeaver.deb 2>/dev/null || true
                apt install -f -y >/dev/null 2>&1
                rm -f /tmp/dbeaver.deb
            }
            command_exists dbeaver-ce && ok "DBeaver instalado." || { fail "DBeaver falló."; FAILED+=("DBeaver"); }
            ;;
        fedora)
            wget -qO /tmp/dbeaver.rpm "https://dbeaver.io/files/dbeaver-ce-latest-stable.x86_64.rpm"
            run_install "DBeaver" rpm -i /tmp/dbeaver.rpm
            rm -f /tmp/dbeaver.rpm
            ;;
        arch)
            yay_install "DBeaver" dbeaver
            ;;
    esac
fi

# =============================================================================
#  15. DOCKER ENGINE + COMPOSE + BUILDX
# =============================================================================
step "15/${TOTAL_STEPS} ─ Instalando Docker Engine + Compose + Buildx"

if command_exists docker; then
    warn "Docker ya está instalado: $(docker --version)"
else
    case "$DISTRO" in
        debian)
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
            chmod a+r /etc/apt/keyrings/docker.gpg

            CODENAME=$(lsb_release -cs 2>/dev/null || echo "${VERSION_CODENAME:-stable}")
            echo "deb [arch=${ARCH_PKG} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} ${CODENAME} stable" \
                > /etc/apt/sources.list.d/docker.list
            apt update >/dev/null 2>&1
            run_install "Docker Engine" apt install -y docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin
            ;;
        fedora)
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || \
                dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || true
            run_install "Docker Engine" dnf install -y docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin
            ;;
        arch)
            yay_install "Docker Engine" docker docker-compose docker-buildx
            ;;
    esac

    if command_exists docker; then
        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
        usermod -aG docker "$REAL_USER" 2>/dev/null && \
            info "Usuario '${REAL_USER}' agregado al grupo docker."
        ok "Docker Engine configurado."
    fi
fi

# =============================================================================
#  16. DOCKER DESKTOP
# =============================================================================
step "16/${TOTAL_STEPS} ─ Instalando Docker Desktop"

if command_exists docker-desktop || [[ -f "/opt/docker-desktop/bin/docker-desktop" ]]; then
    warn "Docker Desktop ya está instalado."
else
    case "$DISTRO" in
        debian)
            info "Descargando Docker Desktop .deb (${ARCH_PKG})..."
            wget -qO /tmp/docker-desktop.deb \
                "https://desktop.docker.com/linux/main/${ARCH_PKG}/docker-desktop-amd64.deb" 2>/dev/null && {
                apt install -y /tmp/docker-desktop.deb >/dev/null 2>&1 || apt install -f -y >/dev/null 2>&1
                rm -f /tmp/docker-desktop.deb
                (command_exists docker-desktop || [[ -f "/opt/docker-desktop/bin/docker-desktop" ]]) && \
                    ok "Docker Desktop instalado." || { fail "Docker Desktop falló."; FAILED+=("Docker Desktop"); }
            } || {
                fail "No se pudo descargar Docker Desktop."
                info "Descárgalo de: https://docs.docker.com/desktop/install/linux/"
                FAILED+=("Docker Desktop")
            }
            ;;
        fedora)
            info "Descargando Docker Desktop .rpm..."
            wget -qO /tmp/docker-desktop.rpm \
                "https://desktop.docker.com/linux/main/${ARCH_PKG}/docker-desktop-x86_64.rpm" 2>/dev/null && {
                run_install "Docker Desktop" dnf install -y /tmp/docker-desktop.rpm
                rm -f /tmp/docker-desktop.rpm
            } || {
                fail "No se pudo descargar Docker Desktop."
                info "Descárgalo de: https://docs.docker.com/desktop/install/linux/"
                FAILED+=("Docker Desktop")
            }
            ;;
        arch)
            yay_install "Docker Desktop" docker-desktop
            ;;
    esac

    if command_exists docker-desktop 2>/dev/null || [[ -f "/opt/docker-desktop/bin/docker-desktop" ]]; then
        systemctl --user enable docker-desktop 2>/dev/null || true
        info "Docker Desktop listo. Ábrelo desde el menú de aplicaciones."
    fi
fi

# =============================================================================
#  17. PEAZIP (GTK2)
# =============================================================================
step "17/${TOTAL_STEPS} ─ Instalando PeaZip (GTK2)"

if command_exists peazip; then
    warn "PeaZip ya está instalado."
else
    PEAZIP_VER=$(curl -fsSL "https://api.github.com/repos/peazip/PeaZip/releases/latest" \
        | grep -oP '"tag_name":\s*"\K[^"]+' | head -1) || true
    PEAZIP_NUM="${PEAZIP_VER#v}"

    case "$DISTRO" in
        debian)
            if [[ -n "${PEAZIP_VER:-}" ]]; then
                info "Descargando PeaZip GTK2 v${PEAZIP_NUM} .deb..."
                wget -qO /tmp/peazip.deb \
                    "https://github.com/peazip/PeaZip/releases/download/${PEAZIP_VER}/peazip_${PEAZIP_NUM}.LINUX.GTK2-1_amd64.deb" 2>/dev/null && {
                    dpkg -i /tmp/peazip.deb 2>/dev/null || true
                    apt install -f -y >/dev/null 2>&1
                    rm -f /tmp/peazip.deb
                    command_exists peazip && ok "PeaZip GTK2 instalado." || { fail "PeaZip falló."; FAILED+=("PeaZip"); }
                } || {
                    fail "No se pudo descargar PeaZip GTK2 .deb"
                    info "Descárgalo de: https://peazip.github.io/peazip-linux.html"
                    FAILED+=("PeaZip")
                }
            else
                fail "No se pudo obtener la versión de PeaZip."
                FAILED+=("PeaZip")
            fi
            ;;
        fedora)
            if [[ -n "${PEAZIP_VER:-}" ]]; then
                info "Descargando PeaZip GTK2 v${PEAZIP_NUM} .rpm..."
                wget -qO /tmp/peazip.rpm \
                    "https://github.com/peazip/PeaZip/releases/download/${PEAZIP_VER}/peazip-${PEAZIP_NUM}.LINUX.GTK2-1.x86_64.rpm" 2>/dev/null && {
                    run_install "PeaZip GTK2" rpm -i /tmp/peazip.rpm
                    rm -f /tmp/peazip.rpm
                } || {
                    fail "No se pudo descargar PeaZip GTK2 .rpm"
                    info "Descárgalo de: https://peazip.github.io/peazip-linux.html"
                    FAILED+=("PeaZip")
                }
            else
                fail "No se pudo obtener la versión de PeaZip."
                FAILED+=("PeaZip")
            fi
            ;;
        arch)
            yay_install "PeaZip GTK2" peazip-gtk2-bin
            ;;
    esac
fi

# =============================================================================
#  18. FIREFOX
# =============================================================================
step "18/${TOTAL_STEPS} ─ Instalando Firefox"

if command_exists firefox; then
    warn "Firefox ya está instalado: $(firefox --version 2>/dev/null)"
else
    case "$DISTRO" in
        debian)
            if [[ "$OS_ID" == "ubuntu" ]]; then
                info "Instalando Firefox desde repo de Mozilla (sin snap)..."
                install -m 0755 -d /etc/apt/keyrings
                wget -qO- https://packages.mozilla.org/apt/repo-signing-key.gpg \
                    | tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null 2>&1
                echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
                    > /etc/apt/sources.list.d/mozilla.list
                cat > /etc/apt/preferences.d/mozilla <<'EOF'
Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 1001
EOF
                apt update >/dev/null 2>&1
                run_install "Firefox" apt install -y firefox
            else
                run_install "Firefox" apt install -y firefox-esr
            fi
            ;;
        fedora)
            run_install "Firefox" dnf install -y firefox
            ;;
        arch)
            yay_install "Firefox" firefox
            ;;
    esac
fi

# =============================================================================
#  19. BRAVE BROWSER
# =============================================================================
step "19/${TOTAL_STEPS} ─ Instalando Brave Browser"

if command_exists brave-browser || command_exists brave; then
    warn "Brave ya está instalado."
else
    case "$DISTRO" in
        debian)
            info "Agregando repositorio de Brave..."
            curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
                https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg 2>/dev/null
            echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
                > /etc/apt/sources.list.d/brave-browser-release.list
            apt update >/dev/null 2>&1
            run_install "Brave Browser" apt install -y brave-browser
            ;;
        fedora)
            info "Agregando repositorio de Brave..."
            dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo 2>/dev/null || \
                dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo 2>/dev/null || true
            rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc 2>/dev/null || true
            run_install "Brave Browser" dnf install -y brave-browser
            ;;
        arch)
            yay_install "Brave Browser" brave-bin
            ;;
    esac
fi

# =============================================================================
#  20. FASTFETCH
# =============================================================================
step "20/${TOTAL_STEPS} ─ Instalando Fastfetch"

if command_exists fastfetch; then
    warn "Fastfetch ya está instalado: $(fastfetch --version 2>/dev/null)"
else
    case "$DISTRO" in
        debian)
            # Intentar desde repo oficial (Ubuntu 24.04+ / Debian 13+ lo tienen)
            if apt-cache show fastfetch >/dev/null 2>&1; then
                run_install "Fastfetch" apt install -y fastfetch
            else
                info "No disponible en repos. Descargando .deb desde GitHub..."
                FF_VER=$(curl -fsSL "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" \
                    | grep -oP '"tag_name":\s*"\K[^"]+' | head -1) || true
                FF_NUM="${FF_VER#v}"

                if [[ -n "${FF_VER:-}" ]]; then
                    wget -qO /tmp/fastfetch.deb \
                        "https://github.com/fastfetch-cli/fastfetch/releases/download/${FF_VER}/fastfetch-linux-${ARCH_PKG}.deb" 2>/dev/null && {
                        dpkg -i /tmp/fastfetch.deb 2>/dev/null || true
                        apt install -f -y >/dev/null 2>&1
                        rm -f /tmp/fastfetch.deb
                        command_exists fastfetch && ok "Fastfetch instalado." || { fail "Fastfetch falló."; FAILED+=("Fastfetch"); }
                    } || {
                        fail "No se pudo descargar Fastfetch."
                        FAILED+=("Fastfetch")
                    }
                else
                    fail "No se pudo obtener la versión de Fastfetch."
                    FAILED+=("Fastfetch")
                fi
            fi
            ;;
        fedora)
            run_install "Fastfetch" dnf install -y fastfetch
            ;;
        arch)
            yay_install "Fastfetch" fastfetch
            ;;
    esac
fi

# Agregar fastfetch al inicio de la terminal (opcional, ejecuta al abrir Zsh)
if command_exists fastfetch; then
    add_to_zshrc "Fastfetch" 'fastfetch'
fi

# =============================================================================
#  RESUMEN FINAL
# =============================================================================
step "INSTALACIÓN COMPLETADA"

echo -e "${BOLD}Sistema:${NC}          ${OS_PRETTY}"
echo -e "${BOLD}Familia:${NC}          ${DISTRO}"
echo -e "${BOLD}Gestor:${NC}           ${PKG_MANAGER}"
echo -e "${BOLD}Arquitectura:${NC}     ${ARCH_HW} (${ARCH_PKG})"
echo ""

TOOLS=(
    "Zsh + Oh My Zsh + plugins"
    "Homebrew (Linuxbrew)"
    "BellSoft Liberica JDK 21"
    "net-tools"
    "Visual Studio Code"
    "VS Code Insiders"
    "macchanger"
    "build-essential / GCC"
    "jEnv"
    "pyenv"
    "JetBrains Toolbox"
    "DBeaver CE"
    "Docker Engine + Compose"
    "Docker Desktop"
    "PeaZip (GTK2)"
    "Firefox"
    "Brave Browser"
    "Fastfetch"
)

echo -e "${GREEN}${BOLD}Herramientas (${#TOOLS[@]}):${NC}"
for tool in "${TOOLS[@]}"; do
    is_failed=false
    for f in "${FAILED[@]+"${FAILED[@]}"}"; do
        if [[ "$tool" == *"$f"* ]]; then
            is_failed=true
            break
        fi
    done
    if $is_failed; then
        echo -e "  ${RED}✗${NC}  ${tool}"
    else
        echo -e "  ${GREEN}✓${NC}  ${tool}"
    fi
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}Fallaron (${#FAILED[@]}):${NC}"
    for item in "${FAILED[@]}"; do
        echo -e "  ${RED}•${NC} ${item}"
    done
fi

echo ""
echo -e "${YELLOW}${BOLD}Acciones post-instalación:${NC}"
echo ""
echo -e "  ${BOLD}1.${NC} Cierra sesión y vuelve a entrar para activar:"
echo "     • Zsh como shell por defecto"
echo "     • Grupo docker (usar docker sin sudo)"
echo "     • Variables de entorno (JAVA_HOME, pyenv, jenv, brew)"
echo "     • Fastfetch al abrir la terminal"
echo ""
echo -e "  ${BOLD}2.${NC} Registra el JDK en jEnv:"
echo "     jenv add /ruta/al/jdk"
echo ""
echo -e "  ${BOLD}3.${NC} Instala una versión de Python con pyenv:"
echo "     pyenv install 3.12 && pyenv global 3.12"
echo ""
echo -e "  ${BOLD}4.${NC} Abre JetBrains Toolbox para instalar tus IDEs:"
echo "     jetbrains-toolbox"
echo ""
echo -e "  ${BOLD}5.${NC} Abre Docker Desktop desde el menú de aplicaciones."
echo ""
echo -e "  ${BOLD}6.${NC} Configura Brave como navegador por defecto (si lo deseas):"
echo "     xdg-settings set default-web-browser brave-browser.desktop"
echo ""
ok "¡Listo! Tu entorno de desarrollo está configurado."