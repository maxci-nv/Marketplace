#!/bin/bash

set -Eeuo pipefail

source ../common.sh


DEFAULT_JENKINS_DIR="/opt/jenkins"
DEFAULT_JENKINS_PORT="8088"


header \
"Jenkins Installation" \
"This script installs Jenkins in Docker."


step "Checking system"

info "Checking root privileges"
check_root

info "Checking docker"
check_docker

info "Checking old jenkins"
if docker ps --format '{{.Names}}' | grep -q "^jenkins$"; then
    warning "Jenkins container is already running"

    ask_yes_no "Continue anyway?" || exit 0
fi

success


step "Configuration"

JENKINS_DIR=$(ask_directory "Installation directory" "$DEFAULT_JENKINS_DIR")
JENKINS_PORT=$(ask_port "HTTP port" "$DEFAULT_JENKINS_PORT")

echo
echo "Configuration Summary"
echo "---------------------"
echo "Directory : $JENKINS_DIR"
echo "Port      : $JENKINS_PORT"
echo

ask_yes_no "Continue installation?" || exit 0

success


step "Generating configuration"

if [[ -f "${JENKINS_DIR}/docker-compose.yml" ]]; then
    warning "Existing Jenkins installation detected in ${JENKINS_DIR}"

    ask_yes_no "Overwrite existing configuration?" || exit 0
fi

info "Creating ${JENKINS_DIR}"
run mkdir -p "${JENKINS_DIR}"

info "Creating Jenkins home directory"
JENKINS_UID=1000
JENKINS_GID=1000
run mkdir -p "${JENKINS_DIR}/jenkins_home"
run chown -R ${JENKINS_UID}:${JENKINS_GID} "${JENKINS_DIR}/jenkins_home"

info "Generating Dockerfile"

cat > "${JENKINS_DIR}/Dockerfile" <<'EOF'
FROM jenkins/jenkins:lts-jdk17

USER root

RUN apt-get update && \
    apt-get install -y \
      git \
      curl && \
    apt-get clean


COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker

USER jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

RUN jenkins-plugin-cli \
      --plugin-file \
      /usr/share/jenkins/ref/plugins.txt
EOF

info "Generating plugins.txt"

cat > "${JENKINS_DIR}/plugins.txt" <<'EOF'
git
workflow-aggregator
pipeline-stage-view
docker-workflow
github
ssh-agent
credentials-binding
job-dsl
configuration-as-code
EOF

info "Generating docker-compose.yml"

if ! getent group docker >/dev/null; then
    error "Docker group not found"
    exit 1
fi

DOCKER_GID=$(getent group docker | cut -d: -f3)

cat > "${JENKINS_DIR}/docker-compose.yml" <<EOF
services:

  jenkins:

    build:
      context: ${JENKINS_DIR}
      dockerfile: Dockerfile

    container_name: jenkins

    restart: unless-stopped

    ports:
      - "${JENKINS_PORT}:8080"

    volumes:
      - ${JENKINS_DIR}/jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock

    group_add:
      - "${DOCKER_GID}"
EOF

success


step "Starting Jenkins"

info "Building Docker image"
run docker compose -f "${JENKINS_DIR}/docker-compose.yml" up -d --build

if ! docker ps --format '{{.Names}}' | grep -q "^jenkins$"; then
    error "Jenkins container failed to start"
    docker logs jenkins
    exit 1
fi

info "Configuring firewall"
if ! command -v firewall-cmd >/dev/null; then
    warning "firewalld is not installed (firewall-cmd not found)."
    warning "Port ${JENKINS_PORT} was NOT opened automatically."
    warning "Open it manually if required."
else
    info "Opening port ${JENKINS_PORT}/tcp"
    run firewall-cmd --permanent --add-port=${JENKINS_PORT}/tcp
    run firewall-cmd --reload
fi

info "Waiting for Jenkins startup"

JENKINS_READY=false

for i in {1..30}; do

    if docker exec jenkins \
        test -f /var/jenkins_home/secrets/initialAdminPassword
    then
        JENKINS_READY=true
        break
    fi

    sleep 5
done


if [[ "${JENKINS_READY}" != "true" ]]; then
    error "Jenkins did not become ready"
    docker logs jenkins
    exit 1
fi

success


step "Jenkins installed"

info "Jenkins URL:"
echo "http://$(hostname -I | awk '{print $1}'):${JENKINS_PORT}"

INIT_ADMIN_PWD=$(docker exec jenkins \
    cat /var/jenkins_home/secrets/initialAdminPassword)
echo "Initial Jenkins password: ${INIT_ADMIN_PWD}"


footer