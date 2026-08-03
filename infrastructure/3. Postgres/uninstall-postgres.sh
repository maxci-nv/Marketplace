#!/bin/bash

set -Eeuo pipefail

source ../common.sh


DEFAULT_POSTGRES_DIR="/opt/postgres"
CONTAINER_NAME="postgres"


header \
"Postgres Removal" \
"This script removes Postgres from Docker."


step "Checking system"

info "Checking root privileges"
check_root

info "Checking docker"
check_docker

success


step "Configuration"

POSTGRES_DIR=$(ask_directory \
    "Postgres installation directory" \
    "${DEFAULT_POSTGRES_DIR}")

echo
echo "Configuration Summary"
echo "---------------------"
echo "Directory : ${POSTGRES_DIR}"
echo

ask_yes_no "Continue removal?" || exit 0

success


step "Removing Postgres"

if [[ -f "${POSTGRES_DIR}/docker-compose.yml" ]]; then

    info "Stopping Postgres"

    run docker compose \
        -f "${POSTGRES_DIR}/docker-compose.yml" \
        down

else
    warning "docker-compose.yml not found"
fi


if container_exists "${CONTAINER_NAME}"; then
    info "Removing Postgres container"
    run docker rm -f "${CONTAINER_NAME}"
fi


if ask_yes_no "Remove Postgres data (${POSTGRES_DIR}/data)?"; then
    run rm -rf "${POSTGRES_DIR}/data"
else
    info "Keeping Postgres data"
fi


if ask_yes_no "Remove Postgres configuration (${POSTGRES_DIR})?"; then

    run rm -f "${POSTGRES_DIR}//docker-compose.init.yml"
    run rm -f "${POSTGRES_DIR}/docker-compose.yml"

    if [[ -z "$(ls -A "${POSTGRES_DIR}")" ]]; then
        run rmdir "${POSTGRES_DIR}"
    fi

else
    info "Keeping configuration"
fi

success


footer