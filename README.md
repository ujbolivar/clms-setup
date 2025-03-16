# CLMS Frontend Setup

This repository contains a setup script for the Copernicus Land Monitoring Service (CLMS) Frontend development environment. The script automates the installation of all required tools and dependencies, sets up the project, and launches the development environment.

## Prerequisites

Before running the setup script, ensure you meet these requirements:

### GitHub Access (Mandatory)
- **SSH keys** must be set up for your machine to authenticate with GitHub
- You **must be invited** to the EEA organization on GitHub to access the repository

### System Requirements
- **Operating Systems**:
  - macOS
  - Linux (Ubuntu/Debian-based)
  - Windows 10/11 with WSL2 (see Windows-specific setup below)
- **Permissions**: Administrator/sudo access for installing packages (MANDATORY)
- **Disk Space**: At least 10GB free space recommended
- **Memory**: Minimum 4GB RAM recommended

### Windows-Specific Setup
If you're using Windows, follow these steps before running the script:

1. **Enable WSL2 and Virtualization**:
   - Ensure Hyper-V and Virtual Machine Platform features are enabled
   - Install WSL2 using PowerShell as administrator: `wsl --install`
   - Make sure WSL is set to version 2: `wsl --set-default-version 2`
   - Install a Linux distribution (Ubuntu recommended) from the Microsoft Store
   - When you first launch your Linux distribution, you'll need to create a user account with a username and password
   - **IMPORTANT**: This user will automatically have sudo privileges. Write down these credentials in a secure location as you'll need them frequently when running commands with sudo in WSL

2. **Install Windows Terminal** (recommended):
   - Download from [Microsoft Store](https://aka.ms/terminal)
   - This provides a better experience when working with WSL

3. **Install Docker Desktop for Windows**:
   - Download and install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
   - During installation, ensure the "WSL 2 based engine" option is selected
   - After installation, go to Settings > Resources > WSL Integration and enable integration with your Linux distros

4. **Run the script within WSL2**:
   - Open Windows Terminal
   - Switch to your WSL Linux distribution
   - Follow the standard installation steps below

### Network Requirements
- **Internet Connection**: Reliable connection for downloading packages and Docker images
- **Ports**: 8080/8081 (backend) and 3000/3001 (frontend) must be available or the script will use alternate ports

## What the Script Installs

If not already present on your system, the script will install:

- **Git**
- **Node.js v16 (Gallium)** via nvm
- **npm and Yarn 3.x**
- **Docker and Docker Compose**
- **Visual Studio Code**

## Installation Process

1. Download the setup script:
   ```bash
   curl -o clms-setup.sh https://[URL_TO_SCRIPT]
   chmod +x clms-setup.sh
   ```

2. Run the script:
   ```bash
   ./clms-setup.sh
   ```

3. Follow the interactive prompts:
   - The script will request sudo privileges to install system packages
   - You'll be asked to provide an installation directory (or accept the default)
   - You may need to confirm Docker Desktop startup on macOS or Windows (WSL2)
   - The script will notify you of port changes if default ports are in use

## What the Script Does

The script performs these operations:

1. **Prerequisites Check and Installation**
   - Checks and installs required software
   - Configures Node.js and Yarn to correct versions

2. **Project Setup**
   - Clones the [eea/clms-frontend](https://github.com/eea/clms-frontend) repository
   - Configures the develop branch
   - Installs dependencies with `yarn install`
   - Handles `mrs.developer.json` configuration
   - Pulls Docker images (eeacms/clms-frontend and eeacms/clms-backend)

3. **Development Environment Launch**
   - Starts Plone backend (port 8080 or alternate if occupied)
   - Starts frontend development server (port 3000 or alternate if occupied)
   - Opens the project in Visual Studio Code
   - Opens the application in your browser

4. **Maintenance**
   - Keeps processes running until manually terminated with Ctrl+C
   - Provides colored console output for status updates

## Browser Support

The script will attempt to open the application in Google Chrome. If Chrome is not available, it will fall back to your system's default browser.

## Troubleshooting

- **Docker Issues**: 
  - Linux: If you experience Docker permission issues, you may need to log out and log back in for group membership changes to take effect.
  - Windows: Make sure Docker Desktop is running before executing the script in WSL.

- **Port Conflicts**: If ports 8080/3000 are already in use, the script will automatically use ports 8081/3001 instead.

- **Repository Access Issues**: If you encounter "Permission denied" errors during cloning, verify that:
  - Your SSH keys are properly set up
  - You have been invited to the EEA organization on GitHub

- **Sudo Access**: The script requires sudo privileges to install system packages. If you don't have sudo access, you'll need to contact your system administrator.

- **WSL2 Issues**: If experiencing problems with WSL2:
  - Ensure Docker Desktop WSL integration is enabled for your Linux distribution
  - Try restarting Docker Desktop and/or your WSL instance

## Additional Information

The script includes comprehensive error handling and OS-specific accommodations for macOS, Linux, and Windows (via WSL2). It remains running to keep the processes alive until you press Ctrl+C to terminate.

For questions or issues, please contact [appropriate contact person/email].
