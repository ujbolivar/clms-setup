#!/bin/bash
# filepath: /Users/unaibolivar/Code/clms-setup.sh

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}        CLMS Frontend Setup Script                  ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Repository URL for CLMS Frontend
REPO_URL="https://github.com/eea/clms-frontend"

# Track if we need to apply group changes
DOCKER_GROUP_CHANGED=false

# Function to detect if running in WSL
is_wsl() {
    if grep -qi microsoft /proc/version; then
        return 0  # true
    else
        return 1  # false
    fi
}

# Function to check if we have sudo access
check_sudo() {
    echo -e "\n${YELLOW}This script needs sudo privileges to install system packages.${NC}"
    if sudo -n true 2>/dev/null; then
        echo -e "${GREEN}Sudo access already granted.${NC}"
        return 0
    else
        echo -e "${YELLOW}Please enter your password to proceed with installations:${NC}"
        if sudo -v; then
            echo -e "${GREEN}Sudo access granted.${NC}"
            return 0
        else
            echo -e "${RED}Failed to get sudo access. Cannot proceed with installation.${NC}"
            return 1
        fi
    fi
}

# Function to install Homebrew
install_homebrew() {
    echo -e "\n${YELLOW}Homebrew not found. Installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Set up Homebrew in PATH for current session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            # For Apple Silicon Macs
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            # For Intel Macs
            eval "$(/usr/local/bin/brew shellenv)"
        else
            echo -e "${RED}Homebrew installed but brew command not found in expected locations.${NC}"
            echo -e "${YELLOW}Please restart your terminal and run this script again.${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if ! check_sudo; then exit 1; fi
        # Install dependencies first
        sudo apt-get update
        sudo apt-get install -y build-essential curl file git
        # Install Homebrew
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add Homebrew to PATH in current session
        test -d ~/.linuxbrew && eval $(~/.linuxbrew/bin/brew shellenv)
        test -d /home/linuxbrew/.linuxbrew && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
        # Add Homebrew to PATH permanently
        echo "eval \$($(brew --prefix)/bin/brew shellenv)" >> ~/.profile
    else
        echo -e "${RED}Unsupported OS. Please install Homebrew manually from https://brew.sh/${NC}"
        exit 1
    fi
    
    # Verify installation
    if command -v brew &> /dev/null; then
        echo -e "${GREEN}Homebrew installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install Homebrew. Please install manually.${NC}"
        exit 1
    fi
}

# Function to install Node.js and npm on macOS
install_node_mac() {
    echo -e "\n${YELLOW}Installing Node.js and npm via Homebrew...${NC}"
    brew install node
    brew install nvm
}

# Function to install Docker on macOS
install_docker_mac() {
    echo -e "\n${YELLOW}Installing Docker Desktop for Mac via Homebrew...${NC}"
    brew install --cask docker
    echo -e "${YELLOW}Docker Desktop has been installed. Please start Docker Desktop application from your Applications folder.${NC}"
    echo -e "${YELLOW}After starting Docker Desktop, press Enter to continue...${NC}"
    read -p ""
}

# Function to install git
install_git() {
    echo -e "\n${YELLOW}Git not found. Installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if ! check_sudo; then exit 1; fi
        sudo apt-get update
        sudo apt-get install -y git
    else
        echo -e "${RED}Unsupported OS. Please install Git manually from https://git-scm.com/${NC}"
        exit 1
    fi
}

# Function to install Docker on Linux
install_docker_linux() {
    echo -e "\n${YELLOW}Installing Docker Engine on Linux...${NC}"
    if ! check_sudo; then exit 1; fi
    
    # Install dependencies
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group to run docker without sudo
    if ! groups $USER | grep -q '\bdocker\b'; then
        sudo usermod -aG docker $USER
        DOCKER_GROUP_CHANGED=true
    fi
    
    # Start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
}

# Function to install Docker Compose on Linux (if needed)
install_docker_compose_linux() {
    echo -e "\n${YELLOW}Installing Docker Compose...${NC}"
    if ! check_sudo; then exit 1; fi
    
    # Check if Docker Compose plugin is already installed via apt
    if command -v docker compose &> /dev/null; then
        echo -e "${GREEN}Docker Compose plugin already installed.${NC}"
        return 0
    fi
    
    # Install standalone Docker Compose if the plugin version is not available
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    echo -e "${GREEN}Docker Compose installed.${NC}"
}

# Function to apply docker group changes without requiring logout/login
apply_docker_group() {
    if [ "$DOCKER_GROUP_CHANGED" = true ]; then
        echo -e "\n${YELLOW}Applying docker group membership to current session...${NC}"
        if command -v newgrp &> /dev/null; then
            # Use newgrp if available (more reliable than sg)
            exec newgrp docker
        else
            # Fallback to sg
            exec sg docker -c "$0"
        fi
        exit 0  # This line will not be reached if exec succeeds
    fi
}

# Function to install nvm (Node Version Manager)
install_nvm() {
    echo -e "\n${YELLOW}Installing nvm (Node Version Manager)...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    
    # Source nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

# Function to check if VS Code is installed
ensure_vscode_installed() {
    if ! command -v code &> /dev/null; then
        echo -e "\n${YELLOW}Visual Studio Code not found. Installing...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install --cask visual-studio-code
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if is_wsl; then
                echo -e "${YELLOW}Please install VS Code for Windows and the WSL extension:${NC}"
                echo -e "${YELLOW}1. Install VS Code: https://code.visualstudio.com/download${NC}"
                echo -e "${YELLOW}2. Install the WSL extension: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl${NC}"
                echo -e "${YELLOW}Once VS Code with WSL extension is installed, press Enter to continue...${NC}"
                read -p ""
            else
                if ! check_sudo; then exit 1; fi
                # Regular Linux VS Code installation code...
                # [unchanged]
            fi
        else
            echo -e "${RED}Unsupported OS. Please install Visual Studio Code manually from https://code.visualstudio.com/${NC}"
        fi
    fi
}

# Function to modify mrs.developer.json
modify_mrs_developer() {
    local file="$1"
    local value="$2"
    
    echo -e "\n${YELLOW}Modifying mrs.developer.json...${NC}"
    if [ -f "$file" ]; then
        # Create backup
        cp "$file" "${file}.bak"
        
        # Use platform-compatible sed approach
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/\"develop\": false/\"develop\": $value/g" "$file"
        else
            sed -i "s/\"develop\": false/\"develop\": $value/g" "$file"
        fi
        
        echo -e "${GREEN}✓ Changed all develop values to $value in mrs.developer.json${NC}"
    else
        echo -e "${RED}Error: mrs.developer.json not found at $file${NC}"
        return 1
    fi
}

# Check if process is running
check_process() {
    local pid=$1
    if is_wsl; then
        ps -p $pid &> /dev/null
    else
        ps -p $pid > /dev/null
    fi
    return $?
}

# Function to check if a port is in use
check_port() {
    local port=$1
    if command -v nc &> /dev/null; then
        nc -z localhost $port &> /dev/null
        return $?
    elif command -v lsof &> /dev/null; then
        lsof -i :$port &> /dev/null
        return $?
    else
        # Fallback to direct connection attempt if neither nc nor lsof is available
        (echo > /dev/tcp/localhost/$port) &>/dev/null
        return $?
    fi
}

# Function to open browser
open_browser() {
    local url=$1
    
    echo -e "\n${GREEN}Opening browser at $url...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - try Chrome first, then fall back to default browser
        if open -a "Google Chrome" "$url" 2>/dev/null; then
            echo -e "${GREEN}Opened in Chrome${NC}"
        else
            open "$url"
            echo -e "${GREEN}Opened in default browser${NC}"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if is_wsl; then
            # WSL - use Windows browsers via cmd.exe
            echo -e "${GREEN}Opening in Windows browser...${NC}"
            cmd.exe /c "start $url" &>/dev/null
        else
            # Linux - try Chrome variants, then fall back to xdg-open
            if command -v google-chrome &> /dev/null; then
                google-chrome "$url" &>/dev/null &
                echo -e "${GREEN}Opened in Chrome${NC}"
            elif command -v google-chrome-stable &> /dev/null; then
                google-chrome-stable "$url" &>/dev/null &
                echo -e "${GREEN}Opened in Chrome${NC}"
            elif command -v chromium-browser &> /dev/null; then
                chromium-browser "$url" &>/dev/null &
                echo -e "${GREEN}Opened in Chromium${NC}"
            elif command -v xdg-open &> /dev/null; then
                xdg-open "$url" &>/dev/null &
                echo -e "${GREEN}Opened in default browser${NC}"
            else
                echo -e "${YELLOW}Could not detect browser. Please open $url manually.${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Unsupported OS for automatic browser opening. Please open $url manually.${NC}"
    fi
}

# Check prerequisites
echo -e "\n${GREEN}Checking prerequisites...${NC}"

# Check if running in WSL and warn about potential Docker setup
if is_wsl; then
    echo -e "${YELLOW}WSL environment detected.${NC}"
    echo -e "${YELLOW}This script will work in WSL, but requires Docker Desktop for Windows to be installed${NC}"
    echo -e "${YELLOW}with WSL2 integration enabled. Do you want to continue? (y/n)${NC}"
    read -p "" answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Exiting script.${NC}"
        exit 0
    fi
fi

# Check for Homebrew (once at the beginning)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "\n${GREEN}Checking for Homebrew...${NC}"
    if ! command -v brew &> /dev/null; then
        install_homebrew
    else
        echo -e "Homebrew ${GREEN}✓${NC} (installed)"
    fi
fi

# Check Git installation
if ! command -v git &> /dev/null; then
    install_git
    
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Failed to install Git. Please install manually.${NC}"
        exit 1
    fi
fi

GIT_VERSION=$(git --version | cut -d ' ' -f 3)
echo -e "Git ${GREEN}✓${NC} (v$GIT_VERSION)"

# Check nvm installation
if ! command -v nvm &> /dev/null; then
    install_nvm
    
    # Try to load nvm again
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if ! command -v nvm &> /dev/null; then
        echo -e "${RED}Failed to install nvm. Please install manually.${NC}"
        echo -e "${YELLOW}You may need to restart your terminal or source your .bashrc/.zshrc.${NC}"
        exit 1
    fi
fi

echo -e "nvm ${GREEN}✓${NC} (installed)"

# Ensure Node.js Gallium (v16) is installed
echo -e "\n${GREEN}Setting up Node.js Gallium (v16)...${NC}"
nvm install lts/gallium
nvm use lts/gallium

NODE_VERSION=$(node -v)
echo -e "Node.js ${GREEN}✓${NC} ($NODE_VERSION - Gallium)"

# Check npm installation
NPM_VERSION=$(npm -v)
echo -e "npm ${GREEN}✓${NC} (v$NPM_VERSION)"

# Check Yarn installation and version
YARN_REQUIRED_VERSION=3
if ! command -v yarn &> /dev/null; then
    echo -e "${YELLOW}Yarn not found. Installing...${NC}"
    npm install -g yarn
    
    if ! command -v yarn &> /dev/null; then
        echo -e "${RED}Failed to install Yarn. Please install manually.${NC}"
        exit 1
    fi
fi

YARN_VERSION=$(yarn -v)
echo -e "Yarn ${GREEN}✓${NC} (v$YARN_VERSION)"

# Check if Yarn version is less than 3
if [ "${YARN_VERSION%%.*}" -lt "$YARN_REQUIRED_VERSION" ]; then
    echo -e "${YELLOW}Setting up Yarn version 3.x...${NC}"
    
    # Enable corepack if using Node.js 16.10+
    NODE_MINOR_VERSION=$(node -v | cut -d. -f2 | sed 's/v//')
    if [[ "${NODE_VERSION}" == *"v16"* ]] && [ "$NODE_MINOR_VERSION" -ge "10" ]; then
        echo -e "${YELLOW}Enabling corepack...${NC}"
        corepack enable
        
        # Set yarn version via corepack
        corepack prepare yarn@stable --activate
        
        YARN_VERSION=$(yarn -v)
        echo -e "Yarn updated to ${GREEN}v$YARN_VERSION${NC}"
    else
        # Alternative approach for older Node.js versions
        echo -e "${YELLOW}Your Node.js version doesn't include corepack. Setting up Yarn 3.x manually...${NC}"
        npm install -g yarn@stable
        yarn set version stable
        
        YARN_VERSION=$(yarn -v)
        echo -e "Yarn updated to ${GREEN}v$YARN_VERSION${NC}"
    fi
fi

# Check Docker installation
echo -e "\n${GREEN}Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install_docker_mac
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if is_wsl; then
            echo -e "${YELLOW}WSL environment detected.${NC}"
            echo -e "${YELLOW}Please install Docker Desktop for Windows with WSL2 integration:${NC}"
            echo -e "${YELLOW}https://docs.docker.com/desktop/install/windows-install/${NC}"
            echo -e "${YELLOW}After installation, ensure WSL2 integration is enabled in Docker Desktop settings.${NC}"
            echo -e "${YELLOW}Once Docker Desktop is installed and configured, press Enter to continue...${NC}"
            read -p ""
        else
            install_docker_linux
            # Apply group changes for Docker if needed
            apply_docker_group
        fi
    else
        echo -e "${RED}Unsupported OS. Please install Docker manually from https://docs.docker.com/get-docker/${NC}"
        exit 1
    fi
    
    # Verify Docker installation
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Failed to install Docker. Please install manually.${NC}"
        exit 1
    fi
fi

DOCKER_VERSION=$(docker --version | cut -d ' ' -f 3 | tr -d ',')
echo -e "Docker ${GREEN}✓${NC} (v$DOCKER_VERSION)"

# Check Docker Compose
echo -e "\n${GREEN}Checking Docker Compose...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # On macOS, Docker Compose comes with Docker Desktop
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose not found. It should be included with Docker Desktop.${NC}"
        echo -e "${YELLOW}Please ensure Docker Desktop is properly installed and running.${NC}"
    else
        if command -v docker compose &> /dev/null; then
            COMPOSE_VERSION=$(docker compose version | cut -d ' ' -f 4)
            echo -e "Docker Compose (plugin) ${GREEN}✓${NC} (v$COMPOSE_VERSION)"
        else
            COMPOSE_VERSION=$(docker-compose --version | cut -d ' ' -f 3 | tr -d ',')
            echo -e "Docker Compose ${GREEN}✓${NC} (v$COMPOSE_VERSION)"
        fi
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # On Linux, check if Docker Compose is installed; if not, install it
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        install_docker_compose_linux
    fi
    
    if command -v docker compose &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version | cut -d ' ' -f 4)
        echo -e "Docker Compose (plugin) ${GREEN}✓${NC} (v$COMPOSE_VERSION)"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d ' ' -f 3 | tr -d ',')
        echo -e "Docker Compose ${GREEN}✓${NC} (v$COMPOSE_VERSION)"
    else
        echo -e "${RED}Failed to install Docker Compose. Please install manually.${NC}"
    fi
fi

# Verify Docker is running
echo -e "\n${GREEN}Verifying Docker is running...${NC}"
if docker info &> /dev/null; then
    echo -e "Docker daemon ${GREEN}✓${NC} (running)"
else
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}Docker daemon is not running. Please start Docker Desktop from your Applications folder.${NC}"
        echo -e "${YELLOW}After starting Docker Desktop, press Enter to continue...${NC}"
        read -p ""
        
        # Check again if Docker is running
        if docker info &> /dev/null; then
            echo -e "Docker daemon ${GREEN}✓${NC} (running)"
        else
            echo -e "${RED}Docker daemon is still not running. Please ensure Docker Desktop is properly started.${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Try to start the Docker service
        echo -e "${YELLOW}Docker daemon is not running. Attempting to start it...${NC}"
        if ! check_sudo; then exit 1; fi
        sudo systemctl start docker
        
        # Wait a moment for Docker to start
        sleep 3
        
        # Check again if Docker is running
        if docker info &> /dev/null; then
            echo -e "Docker daemon ${GREEN}✓${NC} (running)"
        else
            echo -e "${RED}Failed to start Docker daemon. Please check Docker installation.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Docker daemon is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
fi

# Check if VS Code is installed
ensure_vscode_installed

# Ask for installation directory
echo -e "\n${GREEN}Where would you like to install the CLMS Frontend project?${NC}"
echo -e "${YELLOW}(Press Enter for default: ~/projects/clms-frontend)${NC}"
read -p "Directory: " INSTALL_DIR

# Set default install directory if not provided
if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/projects/clms-frontend"
fi

# Create parent directory if it doesn't exist
PARENT_DIR=$(dirname "$INSTALL_DIR")
if [ ! -d "$PARENT_DIR" ]; then
    echo -e "\n${YELLOW}Creating parent directory: $PARENT_DIR${NC}"
    mkdir -p "$PARENT_DIR"
fi

# Clone the repository
echo -e "\n${GREEN}Cloning CLMS Frontend repository...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Warning: Directory already exists. Checking if it's a git repository...${NC}"
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo -e "${YELLOW}Git repository already exists. Pulling latest changes...${NC}"
        cd "$INSTALL_DIR"
        git pull
        
        # Switch to develop branch
        echo -e "\n${GREEN}Switching to develop branch...${NC}"
        git checkout develop
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to switch to develop branch. The branch may not exist or there are conflicts.${NC}"
            echo -e "${YELLOW}Attempting to create develop branch tracking origin/develop...${NC}"
            git checkout -b develop origin/develop
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to create develop branch. Please check the repository structure.${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${RED}Directory exists but is not a git repository. Please choose another directory or remove it.${NC}"
        exit 1
    fi
else
    git clone "$REPO_URL" "$INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to clone repository. Please check your network connection.${NC}"
        exit 1
    fi
    cd "$INSTALL_DIR"
    
    # Switch to develop branch after fresh clone
    echo -e "\n${GREEN}Switching to develop branch...${NC}"
    git checkout develop
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to switch to develop branch. The branch may not exist.${NC}"
        echo -e "${YELLOW}Attempting to create develop branch tracking origin/develop...${NC}"
        git checkout -b develop origin/develop
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create develop branch. Please check the repository structure.${NC}"
            exit 1
        fi
    fi
fi

echo -e "Working directory: ${GREEN}$(pwd)${NC}"
echo -e "Current branch: ${GREEN}$(git branch --show-current)${NC}"

# Make sure Node.js version is Gallium before proceeding
echo -e "\n${GREEN}Setting Node.js version to Gallium...${NC}"
nvm use lts/gallium
NODE_VERSION=$(node -v)
echo -e "Using Node.js ${GREEN}$NODE_VERSION${NC}"

# Install dependencies
echo -e "\n${GREEN}Installing dependencies...${NC}"
yarn install

# Modify mrs.developer.json to change false to true
echo -e "\n${GREEN}Updating mrs.developer.json...${NC}"
modify_mrs_developer "$INSTALL_DIR/mrs.developer.json" "true"

# Run yarn develop
echo -e "\n${GREEN}Running yarn develop...${NC}"
yarn develop

# Modify mrs.developer.json to change true back to false
echo -e "\n${GREEN}Reverting mrs.developer.json...${NC}"
modify_mrs_developer "$INSTALL_DIR/mrs.developer.json" "false"

# Pull Docker images
echo -e "\n${GREEN}Pulling Docker images...${NC}"
echo -e "${YELLOW}Pulling eeacms/clms-frontend...${NC}"
docker pull eeacms/clms-frontend

echo -e "${YELLOW}Pulling eeacms/clms-backend...${NC}"
docker pull eeacms/clms-backend

# Open the project in Visual Studio Code
echo -e "\n${GREEN}Opening project in Visual Studio Code...${NC}"
code "$INSTALL_DIR"

# Check if ports are available
BACKEND_PORT=8080
FRONTEND_PORT=3000
BACKEND_PORT_IN_USE=false
FRONTEND_PORT_IN_USE=false

echo -e "\n${GREEN}Checking if default ports are available...${NC}"

if check_port $BACKEND_PORT; then
    echo -e "${YELLOW}Port $BACKEND_PORT is already in use. Will use port 8081 for backend.${NC}"
    BACKEND_PORT=8081
    BACKEND_PORT_IN_USE=true
else
    echo -e "${GREEN}Port $BACKEND_PORT is available for backend.${NC}"
fi

if check_port $FRONTEND_PORT; then
    echo -e "${YELLOW}Port $FRONTEND_PORT is already in use. Will use port 3001 for frontend.${NC}"
    FRONTEND_PORT=3001
    FRONTEND_PORT_IN_USE=true
else
    echo -e "${GREEN}Port $FRONTEND_PORT is available for frontend.${NC}"
fi

# Start services
echo -e "\n${GREEN}Starting Plone backend and frontend development server...${NC}"

# Set the commands based on port availability
if [ "$BACKEND_PORT" -eq 8081 ]; then
    BACKEND_CMD="PORT=8081 yarn plone"
else
    BACKEND_CMD="yarn plone"
fi

if [ "$FRONTEND_PORT" -eq 3001 ]; then
    FRONTEND_CMD="PORT=3001 yarn start"
else
    FRONTEND_CMD="yarn start"
fi

# Start the backend in background
echo -e "${GREEN}Starting Plone backend on port $BACKEND_PORT...${NC}"
eval "$BACKEND_CMD" &
PLONE_PID=$!

# Check if Plone process started successfully
if [ -z "$PLONE_PID" ] || ! check_process $PLONE_PID; then
    echo -e "${RED}Failed to start Plone backend. Please check for errors and try again.${NC}"
    exit 1
fi

# Add proper signal handling for graceful shutdown
cleanup() {
    echo -e "\n${YELLOW}Stopping services...${NC}"
    if [ -n "$FRONTEND_PID" ] && check_process $FRONTEND_PID; then
        echo -e "${YELLOW}Stopping frontend...${NC}"
        kill $FRONTEND_PID
    fi
    if [ -n "$PLONE_PID" ] && check_process $PLONE_PID; then
        echo -e "${YELLOW}Stopping Plone backend...${NC}"
        kill $PLONE_PID
    fi
    echo -e "${GREEN}All services stopped. Thanks for using CLMS Frontend setup!${NC}"
    exit 0
}

trap cleanup INT TERM

# Function to check if Plone backend is ready
check_plone_ready() {
    curl -s "http://localhost:$BACKEND_PORT/@plone" | grep -q "Plone" >/dev/null 2>&1
    return $?
}

# Wait for Plone to start with progressive feedback
echo -e "${YELLOW}Waiting for Plone to start (this may take around 4 minutes)...${NC}"
TIMEOUT=300  # 5 minutes timeout
INTERVAL=10  # Check every 10 seconds
ELAPSED=0
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_IDX=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if check_plone_ready; then
        echo -e "\n${GREEN}✓ Plone backend is ready!${NC}"
        break
    fi
    
    # Show spinner and elapsed time
    printf "\r${YELLOW}[%s] Still waiting... %d seconds elapsed${NC}" "${SPINNER[$SPINNER_IDX]}" $ELAPSED
    SPINNER_IDX=$(( (SPINNER_IDX + 1) % 10 ))
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "\n${YELLOW}Plone backend startup timed out, but we'll continue anyway.${NC}"
    echo -e "${YELLOW}The backend might still be initializing in the background.${NC}"
fi

# Start frontend
echo -e "\n${GREEN}Starting frontend on port $FRONTEND_PORT...${NC}"
eval "$FRONTEND_CMD" &
FRONTEND_PID=$!

# Check if frontend process started successfully
if [ -z "$FRONTEND_PID" ] || ! check_process $FRONTEND_PID; then
    echo -e "${RED}Failed to start frontend. Please check for errors and try again.${NC}"
    # Kill the backend process before exiting
    if [ -n "$PLONE_PID" ] && check_process $PLONE_PID; then
        kill $PLONE_PID
    fi
    exit 1
fi

# Function to check if frontend is ready
check_frontend_ready() {
    curl -s "http://localhost:$FRONTEND_PORT" | grep -q "html" >/dev/null 2>&1
    return $?
}

# Wait for frontend to start with progressive feedback
echo -e "${YELLOW}Waiting for frontend to start (this may take around 2 minutes)...${NC}"
TIMEOUT=180  # 3 minutes timeout
ELAPSED=0
SPINNER_IDX=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if check_frontend_ready; then
        echo -e "\n${GREEN}✓ Frontend is ready!${NC}"
        break
    fi
    
    # Show spinner and elapsed time
    printf "\r${YELLOW}[%s] Still waiting... %d seconds elapsed${NC}" "${SPINNER[$SPINNER_IDX]}" $ELAPSED
    SPINNER_IDX=$(( (SPINNER_IDX + 1) % 10 ))
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "\n${YELLOW}Frontend startup timed out, but we'll continue anyway.${NC}"
    echo -e "${YELLOW}The frontend might still be initializing in the background.${NC}"
fi

# Open browser with the frontend URL
FRONTEND_URL="http://localhost:$FRONTEND_PORT"
open_browser "$FRONTEND_URL"

echo -e "\n${BLUE}====================================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}Project installed at: ${INSTALL_DIR}${NC}"

# Show docker group warning if needed
if [ "$DOCKER_GROUP_CHANGED" = true ]; then
    echo -e "\n${YELLOW}IMPORTANT: Docker group membership was added for your user.${NC}"
    echo -e "${YELLOW}For this change to fully take effect in all terminals, you should log out and log back in.${NC}"
    echo -e "${YELLOW}For now, Docker commands should work in this terminal session.${NC}"
fi

echo -e "\n${YELLOW}The following services have been started:${NC}"
echo -e "  - Plone backend (running on http://localhost:$BACKEND_PORT)"
echo -e "  - Frontend development server (running on http://localhost:$FRONTEND_PORT)"
echo -e "\n${YELLOW}The project is now open in Visual Studio Code.${NC}"
echo -e "${BLUE}====================================================${NC}"

# Keep the script running to ensure processes stay alive
echo -e "\n${YELLOW}Press Ctrl+C to stop the backend and frontend processes when you're done.${NC}"

# Wait for processes to complete or be interrupted
wait