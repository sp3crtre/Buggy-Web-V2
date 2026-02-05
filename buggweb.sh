#!/usr/bin/env bash

# ============================================================================
# BuggyWeb Pentesting Environment Manager (BW-PEM)
# Author: Kaizer Andri Baynosa | Spectre
# Version: 3.0.0
# Description: Advanced Docker-based pentesting lab management system
# ============================================================================

# Configuration
readonly CONFIG_DIR="$HOME/.buggyweb"
readonly LOG_FILE="$CONFIG_DIR/buggyweb.log"
readonly STATE_FILE="$CONFIG_DIR/state.db"
readonly NETWORK_FILE="$CONFIG_DIR/network.cfg"
readonly IMAGE_CACHE="$CONFIG_DIR/image_cache.db"
readonly SESSION_DIR="$CONFIG_DIR/sessions"

# Color Palette (BuggyWeb Style)
readonly BW_RED='\033[38;5;196m'      # Bright red for warnings/errors
readonly BW_GREEN='\033[38;5;46m'     # Bright green for success
readonly BW_YELLOW='\033[38;5;226m'   # Bright yellow for information
readonly BW_CYAN='\033[38;5;51m'      # Bright cyan for headers
readonly BW_BLUE='\033[38;5;27m'      # Blue for details
readonly BW_MAGENTA='\033[38;5;201m'  # Magenta for special text
readonly BW_ORANGE='\033[38;5;208m'   # Orange for highlights
readonly BW_GRAY='\033[38;5;245m'     # Gray for disabled/status
readonly BW_RESET='\033[0m'
readonly BW_BOLD='\033[1m'
readonly BW_UNDERLINE='\033[4m'

# ASCII Art - BuggyWeb Style
display_buggyweb_banner() {
    clear
    echo -e "${BW_RED}    =[ ${BW_YELLOW}buggyweb pentesting environment v3.0.0${BW_RED} ]"
    echo -e "${BW_RED}+ --=[ ${BW_CYAN}15 vulnerable targets - 8 categories - 5 presets${BW_RED} ]"
    echo -e "${BW_RED}+ --=[ ${BW_GREEN}automated deployment - session management - analysis${BW_RED} ]"
    echo -e "${BW_RED}+ --=[ ${BW_MAGENTA}free to use, modify, and share under GPLv3${BW_RED} ]${BW_RESET}"
    echo ""
    echo -e "${BW_BLUE}"
    echo "@@@@@@@   @@@  @@@   @@@@@@@@   @@@@@@@@  @@@ @@@  @@@  @@@  @@@  @@@@@@@@  @@@@@@@   "
    echo "@@@@@@@@  @@@  @@@  @@@@@@@@@  @@@@@@@@@  @@@ @@@  @@@  @@@  @@@  @@@@@@@@  @@@@@@@@  "
    echo "@@!  @@@  @@!  @@@  !@@        !@@        @@! !@@  @@!  @@!  @@!  @@!       @@!  @@@  "
    echo "!@   @!@  !@!  @!@  !@!        !@!        !@! @!!  !@!  !@!  !@!  !@!       !@   @!@  "
    echo "@!@!@!@   @!@  !@!  !@! @!@!@  !@! @!@!@   !@!@!   @!!  !!@  @!@  @!!!:!    @!@!@!@   "
    echo "!!!@!!!!  !@!  !!!  !!! !!@!!  !!! !!@!!    @!!!   !@!  !!!  !@!  !!!!!:    !!!@!!!!  "
    echo "!!:  !!!  !!:  !!!  :!!   !!:  :!!   !!:    !!:    !!:  !!:  !!:  !!:       !!:  !!!  "
    echo "!!:  !!!  !!:  !!!  :!!   !!:  :!!   !!:    !!:    !!:  !!:  !!:  !!:       !!:  !!!  "
    echo ":!:  !:!  :!:  !:!  :!:   !::  :!:   !::    :!:    :!:  :!:  :!:  :!:       :!:  !:!  "
    echo " :: ::::  ::::: ::   ::: ::::   ::: ::::     ::     :::: :: :::    :: ::::   :: ::::  "
    echo ":: : ::    : :  :    :: :: :    :: :: :      :       :: :  : :    : :: ::   :: : ::   "
    echo -e "${BW_RESET}"
    echo -e "${BW_GRAY}  Author: Kaizer Andri Baynosa | SPECTRE ]"
    echo -e "${BW_RESET}"
}


check_docker_installation() {
    echo -e "${BW_CYAN}[*] Checking Docker installation...${BW_RESET}"
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${BW_YELLOW}[!] Docker is not installed${BW_RESET}"
        
        if confirm_action "Would you like to install Docker automatically?"; then
            install_docker_auto
        else
            echo -e "${BW_RED}[-] Docker is required for BuggyWeb. Exiting.${BW_RESET}"
            exit 1
        fi
    else
        echo -e "${BW_GREEN}[+] Docker is installed${BW_RESET}"
        
        # Check Docker version
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        echo -e "${BW_CYAN}[*] Docker version: $docker_version${BW_RESET}"
    fi
}

check_docker_service() {
    echo -e "${BW_CYAN}[*] Checking Docker service status...${BW_RESET}"
    
    # Try different methods to check if Docker daemon is running
    if docker info &> /dev/null; then
        echo -e "${BW_GREEN}[+] Docker daemon is running${BW_RESET}"
        return 0
    else
        echo -e "${BW_YELLOW}[!] Docker daemon is not running${BW_RESET}"
        
        # Try to start Docker based on OS
        local os_type=$(uname -s)
        case "$os_type" in
            Linux*)
                echo -e "${BW_CYAN}[*] Attempting to start Docker service...${BW_RESET}"
                if command -v systemctl &> /dev/null; then
                    sudo systemctl start docker 2>/dev/null
                    sleep 3
                elif command -v service &> /dev/null; then
                    sudo service docker start 2>/dev/null
                    sleep 3
                fi
                ;;
            Darwin*)
                echo -e "${BW_YELLOW}[!] Please start Docker Desktop from Applications${BW_RESET}"
                echo -e "${BW_YELLOW}[!] Then restart BuggyWeb${BW_RESET}"
                return 1
                ;;
            CYGWIN*|MINGW*|MSYS*)
                echo -e "${BW_YELLOW}[!] Please start Docker Desktop from Start Menu${BW_RESET}"
                echo -e "${BW_YELLOW}[!] Then restart BuggyWeb${BW_RESET}"
                return 1
                ;;
        esac
        
        # Check again if Docker started
        if docker info &> /dev/null; then
            echo -e "${BW_GREEN}[+] Docker daemon started successfully${BW_RESET}"
            return 0
        else
            echo -e "${BW_RED}[-] Failed to start Docker daemon${BW_RESET}"
            
            if confirm_action "Would you like to see troubleshooting steps?"; then
                show_docker_troubleshooting
            fi
            
            return 1
        fi
    fi
}

install_docker_auto() {
    echo -e "${BW_GREEN}[+] Starting Docker installation...${BW_RESET}"
    
    local os_type=$(uname -s)
    
    case "$os_type" in
        Linux*)
            install_docker_linux_auto
            ;;
        Darwin*)
            install_docker_macos_auto
            ;;
        CYGWIN*|MINGW*|MSYS*)
            install_docker_windows_auto
            ;;
        *)
            echo -e "${BW_RED}[-] Unsupported operating system: $os_type${BW_RESET}"
            echo -e "${BW_YELLOW}[!] Please install Docker manually from:${BW_RESET}"
            echo -e "${BW_CYAN}    https://docs.docker.com/get-docker/${BW_RESET}"
            exit 1
            ;;
    esac
    
    # Verify installation
    if check_docker_installation && check_docker_service; then
        echo -e "${BW_GREEN}[+] Docker installation completed successfully!${BW_RESET}"
        echo -e "${BW_CYAN}[*] You may need to log out and back in for group changes to take effect${BW_RESET}"
        sleep 2
    else
        echo -e "${BW_RED}[-] Docker installation may have failed${BW_RESET}"
        echo -e "${BW_YELLOW}[!] Please install Docker manually and try again${BW_RESET}"
        exit 1
    fi
}

install_docker_linux_auto() {
    echo -e "${BW_CYAN}[*] Detecting Linux distribution...${BW_RESET}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${BW_CYAN}[*] Detected: $PRETTY_NAME${BW_RESET}"
        
        case "$ID" in
            ubuntu|debian)
                install_docker_debian_auto
                ;;
            centos|rhel|fedora)
                install_docker_redhat_auto
                ;;
            arch)
                install_docker_arch_auto
                ;;
            *)
                echo -e "${BW_YELLOW}[!] Unsupported Linux distribution${BW_RESET}"
                echo -e "${BW_CYAN}[*] Attempting generic Linux installation...${BW_RESET}"
                install_docker_generic_linux
                ;;
        esac
    else
        echo -e "${BW_YELLOW}[!] Cannot detect Linux distribution${BW_RESET}"
        install_docker_generic_linux
    fi
}

install_docker_debian_auto() {
    echo -e "${BW_CYAN}[*] Installing Docker for Debian/Ubuntu...${BW_RESET}"
    
    # Update package lists
    echo -e "${BW_CYAN}[*] Updating package lists...${BW_RESET}"
    sudo apt-get update
    
    # Install prerequisites
    echo -e "${BW_CYAN}[*] Installing prerequisites...${BW_RESET}"
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    echo -e "${BW_CYAN}[*] Adding Docker's GPG key...${BW_RESET}"
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo -e "${BW_CYAN}[*] Setting up Docker repository...${BW_RESET}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package lists again
    sudo apt-get update
    
    # Install Docker
    echo -e "${BW_CYAN}[*] Installing Docker Engine...${BW_RESET}"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    echo -e "${BW_CYAN}[*] Starting Docker service...${BW_RESET}"
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    echo -e "${BW_CYAN}[*] Adding user to docker group...${BW_RESET}"
    sudo usermod -aG docker $USER
    
    echo -e "${BW_GREEN}[+] Docker installation complete for Debian/Ubuntu${BW_RESET}"
}

install_docker_redhat_auto() {
    echo -e "${BW_CYAN}[*] Installing Docker for RHEL/CentOS/Fedora...${BW_RESET}"
    
    # Remove old versions
    sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    
    # Install prerequisites
    echo -e "${BW_CYAN}[*] Installing prerequisites...${BW_RESET}"
    sudo yum install -y yum-utils
    
    # Set up repository
    echo -e "${BW_CYAN}[*] Setting up Docker repository...${BW_RESET}"
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    echo -e "${BW_CYAN}[*] Installing Docker...${BW_RESET}"
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    echo -e "${BW_CYAN}[*] Starting Docker service...${BW_RESET}"
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    echo -e "${BW_CYAN}[*] Adding user to docker group...${BW_RESET}"
    sudo usermod -aG docker $USER
    
    echo -e "${BW_GREEN}[+] Docker installation complete for RHEL/CentOS${BW_RESET}"
}

install_docker_arch_auto() {
    echo -e "${BW_CYAN}[*] Installing Docker for Arch Linux...${BW_RESET}"
    
    # Update system
    sudo pacman -Syu --noconfirm
    
    # Install Docker
    echo -e "${BW_CYAN}[*] Installing Docker...${BW_RESET}"
    sudo pacman -S --noconfirm docker docker-compose
    
    # Start and enable Docker
    echo -e "${BW_CYAN}[*] Starting Docker service...${BW_RESET}"
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    echo -e "${BW_CYAN}[*] Adding user to docker group...${BW_RESET}"
    sudo usermod -aG docker $USER
    
    echo -e "${BW_GREEN}[+] Docker installation complete for Arch Linux${BW_RESET}"
}

install_docker_generic_linux() {
    echo -e "${BW_CYAN}[*] Attempting generic Docker installation...${BW_RESET}"
    
    # Try using get.docker.com script
    echo -e "${BW_CYAN}[*] Downloading Docker installation script...${BW_RESET}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    
    if [ -f get-docker.sh ]; then
        echo -e "${BW_CYAN}[*] Running Docker installation script...${BW_RESET}"
        sudo sh get-docker.sh
        
        # Clean up
        rm get-docker.sh
        
        # Start Docker
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null
        sudo systemctl enable docker 2>/dev/null
        
        # Add user to docker group
        sudo usermod -aG docker $USER 2>/dev/null
        
        echo -e "${BW_GREEN}[+] Docker installation attempt complete${BW_RESET}"
    else
        echo -e "${BW_RED}[-] Failed to download Docker installation script${BW_RESET}"
        echo -e "${BW_YELLOW}[!] Please install Docker manually:${BW_RESET}"
        echo -e "${BW_CYAN}    https://docs.docker.com/engine/install/${BW_RESET}"
        exit 1
    fi
}

install_docker_macos_auto() {
    echo -e "${BW_CYAN}[*] Installing Docker for macOS...${BW_RESET}"
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        echo -e "${BW_CYAN}[*] Installing Homebrew first...${BW_RESET}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install Docker via Homebrew
    echo -e "${BW_CYAN}[*] Installing Docker Desktop via Homebrew...${BW_RESET}"
    brew install --cask docker
    
    echo -e "${BW_GREEN}[+] Docker Desktop installed${BW_RESET}"
    echo -e "${BW_YELLOW}[!] Please start Docker Desktop from Applications folder${BW_RESET}"
    echo -e "${BW_YELLOW}[!] Then restart BuggyWeb${BW_RESET}"
    exit 0
}

install_docker_windows_auto() {
    echo -e "${BW_CYAN}[*] Installing Docker for Windows...${BW_RESET}"
    
    # Check for Chocolatey
    if ! command -v choco &> /dev/null; then
        echo -e "${BW_CYAN}[*] Installing Chocolatey first...${BW_RESET}"
        powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    fi
    
    # Install Docker via Chocolatey
    echo -e "${BW_CYAN}[*] Installing Docker Desktop via Chocolatey...${BW_RESET}"
    choco install docker-desktop -y
    
    echo -e "${BW_GREEN}[+] Docker Desktop installed${BW_RESET}"
    echo -e "${BW_YELLOW}[!] Please start Docker Desktop from Start Menu${BW_RESET}"
    echo -e "${BW_YELLOW}[!] Then restart BuggyWeb${BW_RESET}"
    exit 0
}

show_docker_troubleshooting() {
    echo -e "\n${BW_CYAN}=== Docker Troubleshooting Steps ===${BW_RESET}"
    echo -e "${BW_YELLOW}1. Check if Docker is installed:${BW_RESET}"
    echo -e "   docker --version"
    echo -e "${BW_YELLOW}2. Check Docker service status:${BW_RESET}"
    echo -e "   sudo systemctl status docker"
    echo -e "${BW_YELLOW}3. Start Docker service:${BW_RESET}"
    echo -e "   sudo systemctl start docker"
    echo -e "${BW_YELLOW}4. Enable Docker at boot:${BW_RESET}"
    echo -e "   sudo systemctl enable docker"
    echo -e "${BW_YELLOW}5. Add user to docker group:${BW_RESET}"
    echo -e "   sudo usermod -aG docker $USER"
    echo -e "   (then log out and back in)"
    echo -e "${BW_YELLOW}6. Verify Docker can run without sudo:${BW_RESET}"
    echo -e "   docker run hello-world"
    echo -e "${BW_CYAN}===================================${BW_RESET}\n"
}

bw_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$CONFIG_DIR"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "SUCCESS") echo -e "${BW_GREEN}[+] $message${BW_RESET}" ;;
        "INFO") echo -e "${BW_CYAN}[*] $message${BW_RESET}" ;;
        "WARNING") echo -e "${BW_YELLOW}[!] $message${BW_RESET}" ;;
        "ERROR") echo -e "${BW_RED}[-] $message${BW_RESET}" ;;
        "DEBUG") echo -e "${BW_GRAY}[~] $message${BW_RESET}" ;;
        *) echo -e "[$level] $message" ;;
    esac
}

confirm_action() {
    local message="$1"
    
    while true; do
        echo -ne "${BW_CYAN}$message (yes/no) [no]: ${BW_RESET}"
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]|"") return 1 ;;
            *) echo -e "${BW_YELLOW}[!] Please answer yes or no.${BW_RESET}" ;;
        esac
    done
}

declare -A VULNERABLE_TARGETS=(
    ["web"]="vulnerables/web-dvwa:latest"
    ["webapp"]="bkimminich/juice-shop:latest"
    ["training"]="citizenstig/nowasp:latest"
    ["ctf"]="santosomar/gravemind:latest"
    ["network"]="santosomar/mayhem:latest"
    ["reverse"]="santosomar/hackme-rtov:latest"
    ["cloud"]="owasp/webgoat:latest"
    ["mobile"]="bkimminich/juice-shop-ctf:latest"
    ["iot"]="santosomar/dc30_01:latest"
    ["advanced"]="metasploitable3:latest"
)

declare -A TARGET_METADATA=(
    ["web"]="WEB|DVWA|80|admin:password|SQLi, XSS, CSRF|Low"
    ["webapp"]="WEB|Juice Shop|3000|admin:admin|Modern Web Vulns|Medium"
    ["training"]="WEB|Mutillidae|80|root:toor|OWASP Top 10|Low"
    ["ctf"]="CTF|Gravemind|80,22|root:root|Multi-service|High"
    ["network"]="NET|Mayhem|80,443|admin:admin|Network Services|Medium"
    ["reverse"]="RE|RT Overflow|22,9999|user:pass|Reverse Engineering|High"
    ["cloud"]="EDU|WebGoat|8080|guest:guest|Web Security|Learning"
    ["mobile"]="MOBILE|Juice Shop CTF|3000|ctf:ctf|Mobile Security|Medium"
    ["iot"]="IOT|DC30|80,9000|admin:admin|IoT Challenges|High"
    ["advanced"]="ADV|Metasploitable3|22,80,443|msfadmin:msfadmin|Comprehensive|High"
)


display_main_menu() {
    echo -e "\n${BW_CYAN}    =[ BuggyWeb Main Menu ${BW_RESET}"
    echo -e "${BW_GRAY}    + -- --=[ Select an option:${BW_RESET}"
    
    local menu_items=(
        "Deploy Target"
        "Manage Sessions"
        "Quick Presets"
        "Network Analysis"
        "System Utilities"
        "Docker Status"
        "Exit"
    )
    
    local i=1
    for item in "${menu_items[@]}"; do
        printf "${BW_GREEN}    %2d${BW_RESET}  ${BW_CYAN}%-25s${BW_RESET}\n" "$i" "$item"
        ((i++))
    done
    
    echo -e "${BW_GRAY}    + -- --=[${BW_RESET}"
    echo -ne "${BW_YELLOW}    buggyweb >${BW_RESET} "
}

module_deploy_target() {
    display_buggyweb_banner
    echo -e "${BW_CYAN}    =[ DEPLOY VULNERABLE TARGET ${BW_RESET}"
    
    local categories=(
        "Web Applications"
        "Training & Education"
        "CTF Challenges"
        "Network Services"
        "Custom Target"
        "Back to Main"
    )
    
    echo -e "${BW_GRAY}    + -- --=[ Select category:${BW_RESET}"
    local i=1
    for category in "${categories[@]}"; do
        printf "${BW_GREEN}    %2d${BW_RESET}  ${BW_CYAN}%-25s${BW_RESET}\n" "$i" "$category"
        ((i++))
    done
    echo -e "${BW_GRAY}    + -- --=[${BW_RESET}"
    echo -ne "${BW_YELLOW}    select >${BW_RESET} "
    
    read -r choice
    case $choice in
        1) deploy_category "web" ;;
        2) deploy_category "training" ;;
        3) deploy_category "ctf" ;;
        4) deploy_category "network" ;;
        5) deploy_custom_target ;;
        6) return ;;
        *) bw_log "ERROR" "Invalid selection" ;;
    esac
}

deploy_category() {
    local category="$1"
    
    display_buggyweb_banner
    echo -e "${BW_CYAN}    =[ DEPLOY $category ${BW_RESET}"
    
    # Filter targets by category
    local targets=()
    for key in "${!TARGET_METADATA[@]}"; do
        IFS='|' read -r cat_type <<< "${TARGET_METADATA[$key]}"
        if [[ "$cat_type" == *"$category"* ]] || [[ "$category" == "web" && ("$cat_type" == "WEB" || "$cat_type" == "EDU") ]]; then
            IFS='|' read -r cat_type name ports <<< "${TARGET_METADATA[$key]}"
            targets+=("$key:$name (Ports: $ports)")
        fi
    done
    
    if [ ${#targets[@]} -eq 0 ]; then
        bw_log "ERROR" "No targets found in category: $category"
        return
    fi
    
    echo -e "${BW_GRAY}    + -- --=[ Available targets:${BW_RESET}"
    local i=1
    for target in "${targets[@]}"; do
        printf "${BW_GREEN}    %2d${BW_RESET}  ${BW_CYAN}%-40s${BW_RESET}\n" "$i" "$target"
        ((i++))
    done
    echo -e "${BW_GRAY}    + -- --=[${BW_RESET}"
    echo -ne "${BW_YELLOW}    target >${BW_RESET} "
    
    read -r target_choice
    if [ "$target_choice" -ge 1 ] && [ "$target_choice" -le ${#targets[@]} ]; then
        local selected="${targets[$((target_choice-1))]}"
        local target_key="${selected%%:*}"
        launch_target "$target_key"
    else
        bw_log "ERROR" "Invalid target selection"
    fi
}

launch_target() {
    local target_key="$1"
    
    # Verify Docker is running
    if ! check_docker_service; then
        bw_log "ERROR" "Cannot launch target without Docker"
        return
    fi
    
    local image="${VULNERABLE_TARGETS[$target_key]}"
    local metadata="${TARGET_METADATA[$target_key]}"
    IFS='|' read -r category name port credentials vulnerabilities difficulty <<< "$metadata"
    
    bw_log "INFO" "Deploying: $name"
    bw_log "INFO" "Type: $category | Difficulty: $difficulty"
    bw_log "INFO" "Vulnerabilities: $vulnerabilities"
    
    # Generate container name
    local container_name="bw_${target_key}_$(date +%s)"
    
    # Pull image if needed
    if ! docker image inspect "$image" &> /dev/null; then
        bw_log "INFO" "Downloading target image..."
        docker pull "$image" || {
            bw_log "ERROR" "Failed to download image"
            return
        }
    fi
    
    # Deploy container
    bw_log "INFO" "Starting container: $container_name"
    
    if docker run -d --name "$container_name" -P "$image"; then
        local container_id=$(docker ps -q -f "name=$container_name")
        local ip_addr=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_id")
        local ports=$(docker port "$container_id")
        
        echo -e "\n${BW_GREEN}    [+] TARGET DEPLOYED SUCCESSFULLY${BW_RESET}"
        echo -e "${BW_GRAY}    + -- --=[ Connection Details:${BW_RESET}"
        echo -e "${BW_CYAN}    Name:${BW_RESET} $name"
        echo -e "${BW_CYAN}    Container:${BW_RESET} $container_name"
        echo -e "${BW_CYAN}    IP:${BW_RESET} $ip_addr"
        
        if [ -n "$credentials" ]; then
            echo -e "${BW_CYAN}    Credentials:${BW_RESET} $credentials"
        fi
        
        echo -e "${BW_CYAN}    Access URLs:${BW_RESET}"
        while IFS= read -r line; do
            local port_info=$(echo "$line" | awk '{print $3}')
            echo -e "        http://localhost:${port_info#*:}"
        done <<< "$ports"
        
        # Save to session
        save_session "$container_id" "$container_name" "$image" "$name"
        
        bw_log "SUCCESS" "Target ready for testing"
    else
        bw_log "ERROR" "Failed to start container"
    fi
    
    echo -ne "${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
    read -r
}

save_session() {
    local container_id="$1"
    local container_name="$2"
    local image="$3"
    local target_name="$4"
    
    mkdir -p "$SESSION_DIR"
    local session_id="sess_$(date +%s)"
    local session_file="$SESSION_DIR/$session_id.info"
    
    cat > "$session_file" << EOF
SESSION_ID=$session_id
CONTAINER_ID=$container_id
CONTAINER_NAME=$container_name
TARGET_NAME=$target_name
IMAGE=$image
DEPLOY_TIME=$(date -Iseconds)
EOF
    
    bw_log "INFO" "Session saved: $session_id"
}

module_docker_status() {
    display_buggyweb_banner
    echo -e "${BW_CYAN}    =[ DOCKER STATUS ${BW_RESET}"
    
    check_docker_installation
    check_docker_service
    
    if docker info &> /dev/null; then
        echo -e "\n${BW_GREEN}    [+] DOCKER DETAILS${BW_RESET}"
        echo -e "${BW_GRAY}    + -- --=[${BW_RESET}"
        
        # Show Docker info
        echo -e "${BW_CYAN}    Version:${BW_RESET} $(docker --version | cut -d' ' -f3- | tr -d ',')"
        echo -e "${BW_CYAN}    API Version:${BW_RESET} $(docker version --format '{{.Server.APIVersion}}' 2>/dev/null || echo 'N/A')"
        
        # Show containers
        local running_count=$(docker ps -q | wc -l)
        local total_count=$(docker ps -aq | wc -l)
        echo -e "${BW_CYAN}    Containers:${BW_RESET} $running_count running, $total_count total"
        
        # Show images
        local image_count=$(docker images -q | wc -l)
        echo -e "${BW_CYAN}    Images:${BW_RESET} $image_count"
        
        # Show BuggyWeb containers
        echo -e "\n${BW_CYAN}    BuggyWeb Managed Containers:${BW_RESET}"
        docker ps --filter "name=bw_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2
        
        if [ "$running_count" -gt 0 ]; then
            echo -e "\n${BW_CYAN}    Resource Usage:${BW_RESET}"
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -6
        fi
    fi
    
    echo -ne "\n${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
    read -r
}

main_loop() {
    while true; do
        display_buggyweb_banner
        display_main_menu
        
        read -r choice
        case $choice in
            1) module_deploy_target ;;
            2) module_manage_sessions ;;
            3) module_quick_presets ;;
            4) module_network_analysis ;;
            5) module_system_utilities ;;
            6) module_docker_status ;;
            7) 
                echo -e "\n${BW_GREEN}[+] Shutting down BuggyWeb...${BW_RESET}"
                exit 0
                ;;
            clear|cls)
                clear
                ;;
            help|?)
                show_help
                ;;
            *)
                bw_log "ERROR" "Invalid option: $choice"
                echo -ne "${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
                read -r
                ;;
        esac
    done
}

show_help() {
    echo -e "\n${BW_GREEN}    [+] BUGGYWEB COMMAND REFERENCE${BW_RESET}"
    echo -e "${BW_GRAY}    + -- --=[${BW_RESET}"
    echo -e "${BW_CYAN}    1${BW_RESET} - Deploy vulnerable targets"
    echo -e "${BW_CYAN}    2${BW_RESET} - Manage active sessions"
    echo -e "${BW_CYAN}    3${BW_RESET} - Quick deployment presets"
    echo -e "${BW_CYAN}    4${BW_RESET} - Network analysis tools"
    echo -e "${BW_CYAN}    5${BW_RESET} - System utilities"
    echo -e "${BW_CYAN}    6${BW_RESET} - Docker status and info"
    echo -e "${BW_CYAN}    7${BW_RESET} - Exit BuggyWeb"
    echo -e "${BW_CYAN}    clear${BW_RESET} - Clear screen"
    echo -e "${BW_CYAN}    help${BW_RESET} - Show this help"
    echo -ne "${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
    read -r
}

# Stub functions for unimplemented modules
module_manage_sessions() {
    bw_log "INFO" "Session management module - Coming soon!"
    echo -ne "${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
    read -r
}

module_quick_presets() {
    bw_log "INFO" "Quick presets module - Coming soon!"
    echo -ne "${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
    read -r
}

module_network_analysis() {
    bw_log "INFO" "Network analysis module - Coming soon!"
    echo -ne "${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
    read -r
}

module_system_utilities() {
    bw_log "INFO" "System utilities module - Coming soon!"
    echo -ne "${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
    read -r
}

deploy_custom_target() {
    echo -e "\n${BW_CYAN}    =[ CUSTOM TARGET DEPLOYMENT ${BW_RESET}"
    echo -ne "${BW_YELLOW}    Enter Docker image name: ${BW_RESET}"
    read -r custom_image
    
    if [ -z "$custom_image" ]; then
        bw_log "ERROR" "No image specified"
        return
    fi
    
    if ! check_docker_service; then
        bw_log "ERROR" "Cannot deploy without Docker"
        return
    fi
    
    bw_log "INFO" "Deploying custom image: $custom_image"
    
    local container_name="bw_custom_$(date +%s)"
    
    if docker run -d --name "$container_name" -P "$custom_image"; then
        bw_log "SUCCESS" "Custom container deployed: $container_name"
        local ports=$(docker port "$container_name")
        echo -e "${BW_CYAN}    Access ports:${BW_RESET}"
        echo "$ports"
    else
        bw_log "ERROR" "Failed to deploy custom image"
    fi
    
    echo -ne "${BW_YELLOW}    Press Enter to continue...${BW_RESET}"
    read -r
}

initialize_buggyweb() {
    # Create configuration directory
    mkdir -p "$CONFIG_DIR" "$SESSION_DIR"
    
    # Show banner
    display_buggyweb_banner
    
    # Check and setup Docker
    echo -e "${BW_CYAN}[*] Initializing BuggyWeb Environment...${BW_RESET}"
    
    check_docker_installation
    if ! check_docker_service; then
        echo -e "${BW_RED}[-] Docker is required for BuggyWeb${BW_RESET}"
        if confirm_action "Would you like to try automatic Docker installation?"; then
            install_docker_auto
        else
            echo -e "${BW_RED}[-] Exiting BuggyWeb${BW_RESET}"
            exit 1
        fi
    fi
    
    bw_log "SUCCESS" "BuggyWeb initialized successfully"
    bw_log "INFO" "Type 'help' for command reference"
    sleep 2
}


# Trap Ctrl+C
trap 'echo -e "\n${BW_RED}[-] Interrupted${BW_RESET}"; exit 1' INT

# Start BuggyWeb
initialize_buggyweb
main_loop
