#!/bin/bash

set -Eeuo pipefail

source ../common.sh


header \
"Docker Installation" \
"This script installs:

 • Docker Engine
 • Docker Compose Plugin"


step "Checking system"

info "Checking root privileges"
check_root

info "Checking DNF"
check_dnf

success


if check_docker; then
    step "Docker"
    warning "Docker is already installed."
else

    step "Installing Docker repository"

    info "Installing DNF plugins"
    run dnf -y install dnf-plugins-core

    info "Adding Docker repository"
    run dnf config-manager \
        --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    success


    step "Installing Docker Engine"

    info "Installing Docker packages"
    run dnf -y install \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
	--disablerepo=packages-microsoft-com-prod

    CURRENT_USER=$(logname 2>/dev/null || echo $SUDO_USER)

    if [ -n "$CURRENT_USER" ]; then
      info "Add user '$CURRENT_USER' to group 'docker'"
      usermod -aG docker "$CURRENT_USER" || true
    fi

    success

fi


step "Starting Docker"

info "Enabling Docker service"
run systemctl enable docker

info "Starting Docker service"
run systemctl start docker

success


step "Verifying installation"

info "Checking Docker daemon"
run check_docker_running

info "Checking Docker Compose"
run check_compose

info "Creating infrastructure network"
run create_network

success


step "Installed components"

echo "    Docker : $(docker --version)"
echo "    Compose: $(docker compose version)"


footer