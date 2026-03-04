# Dev Environment Setup

Script automatizado para configurar un entorno de desarrollo completo en Linux.

Detecta tu distribución (Debian/Ubuntu, Fedora, Arch/Manjaro) e instala **20 herramientas** con un solo comando.

## Ejecución rápida

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/libra1024/linux-basic-tools/main/setup.sh)"
```

### Alternativas

Con `wget`:
```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/libra1024/linux-basic-tools/main/setup.sh)"
```

Clonando el repo:
```bash
git clone https://github.com/libra1024/linux-basic-tools.git
cd linux-basic-tools
sudo bash setup.sh
```

## ¿Qué instala?

| #  | Herramienta              | Debian/Ubuntu       | Fedora              | Arch/Manjaro       |
|----|--------------------------|---------------------|---------------------|--------------------|
| 1  | Zsh + Oh My Zsh          | `apt`               | `dnf`               | `yay`              |
| 2  | Plugins Zsh              | git clone           | git clone           | git clone          |
| 3  | Homebrew (Linuxbrew)     | installer oficial   | installer oficial   | installer oficial  |
| 4  | BellSoft Liberica JDK 21 | repo bellsoft        | repo bellsoft        | `yay` (AUR)        |
| 5  | net-tools                | `apt`               | `dnf`               | `yay`              |
| 6  | VS Code                  | repo Microsoft      | repo Microsoft      | `yay` (AUR)        |
| 7  | VS Code Insiders         | repo Microsoft      | repo Microsoft      | `yay` (AUR)        |
| 8  | macchanger               | `apt`               | `dnf`               | `yay`              |
| 9  | build-essential / GCC    | `apt`               | `dnf` (group)       | `yay`              |
| 10 | jEnv                     | git clone           | git clone           | git clone          |
| 11 | pyenv                    | pyenv installer     | pyenv installer     | pyenv installer    |
| 12 | JetBrains Toolbox        | tar.gz directo      | tar.gz directo      | `yay` (AUR)        |
| 13 | DBeaver CE               | `.deb` directo      | `.rpm` directo      | `yay` (AUR)        |
| 14 | Docker Engine + Compose  | repo Docker         | repo Docker         | `yay`              |
| 15 | Docker Desktop           | `.deb` directo      | `.rpm` directo      | `yay` (AUR)        |
| 16 | PeaZip (GTK2)            | `.deb` GitHub       | `.rpm` GitHub       | `yay` (AUR)        |
| 17 | Firefox                  | repo Mozilla / `apt`| `dnf`               | `yay`              |
| 18 | Brave Browser            | repo Brave          | repo Brave          | `yay` (AUR)        |
| 19 | Fastfetch                | `apt` / GitHub      | `dnf`               | `yay`              |

## Qué configura en `.zshrc`

- Oh My Zsh con plugins: `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `docker`, `docker-compose`
- `JAVA_HOME` apuntando al JDK de BellSoft
- `jenv init`
- `pyenv init` + `virtualenv-init`
- `brew shellenv`
- `fastfetch` al abrir la terminal

## Requisitos

- Distribución soportada: **Debian**, **Ubuntu**, **Fedora**, **Arch** o **Manjaro**
- Acceso a internet
- Ejecutar como `sudo` (el script detecta el usuario real automáticamente)

## Post-instalación

Después de ejecutar el script, cierra sesión y vuelve a entrar. Luego:

```bash
# Verificar que Zsh es tu shell
echo $SHELL

# Registrar JDK en jEnv
jenv add /usr/lib/jvm/bellsoft-java21-amd64

# Instalar Python con pyenv
pyenv install 3.12
pyenv global 3.12

# Abrir JetBrains Toolbox
jetbrains-toolbox

# Abrir Docker Desktop
docker-desktop
```