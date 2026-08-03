#!/bin/bash

set -Eeuo pipefail

source ../common.sh


DEFAULT_JENKINS_DIR="/opt/jenkins"


header \
"Jenkins Removal" \
"This script removes Jenkins from Docker."


step "Checking system"

info "Checking root privileges"
check_root

info "Checking docker"
check_docker

success


step "Configuration"

JENKINS_DIR=$(ask_directory \
    "Jenkins installation directory" \
    "${DEFAULT_JENKINS_DIR}")

echo
echo "Configuration Summary"
echo "---------------------"
echo "Directory : ${JENKINS_DIR}"
echo

ask_yes_no "Continue removal?" || exit 0

success


step "Removing Jenkins"

if [[ -f "${JENKINS_DIR}/docker-compose.yml" ]]; then

    info "Stopping Jenkins"

    run docker compose \
        -f "${JENKINS_DIR}/docker-compose.yml" \
        down

else

    warning "docker-compose.yml not found"

fi


if docker ps -a --format '{{.Names}}' | grep -q '^jenkins$'; then

    info "Removing Jenkins container"

    run docker rm -f jenkins

fi


if ask_yes_no "Remove Jenkins data (${JENKINS_DIR}/jenkins_home)?"; then

    run rm -rf "${JENKINS_DIR}/jenkins_home"

else

    info "Keeping Jenkins data"

fi


if ask_yes_no "Remove Jenkins configuration (${JENKINS_DIR})?"; then

    run rm -f "${JENKINS_DIR}/Dockerfile"
    run rm -f "${JENKINS_DIR}/docker-compose.yml"
    run rm -f "${JENKINS_DIR}/plugins.txt"

    if [[ -z "$(ls -A "${JENKINS_DIR}")" ]]; then
        run rmdir "${JENKINS_DIR}"
    fi

else

    info "Keeping configuration"

fi

success


footer