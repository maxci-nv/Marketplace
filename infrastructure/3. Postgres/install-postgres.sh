#!/bin/bash

set -Eeuo pipefail

source ../common.sh

DEFAULT_POSTGRES_DIR="/opt/postgres"
DEFAULT_POSTGRES_PORT="5432"
CONTAINER_NAME="postgres"

header \
"Postgres Installation" \
"This script installs Postgres in Docker."


step "Checking system"

info "Checking root privileges"
check_root

info "Checking docker"
check_docker

info "Checking Docker network"
create_network

info "Checking old postgres"
if container_exists "${CONTAINER_NAME}"; then
    warning "Postgres container is already running"

    ask_yes_no "Continue anyway?" || exit 0
fi

success


step "Configuration"

POSTGRES_DIR=$(ask_directory "Installation directory" "$DEFAULT_POSTGRES_DIR")
POSTGRES_PORT=$(ask_port "Postgres port" "$DEFAULT_POSTGRES_PORT")
POSTGRES_USER=$(ask_username "Postgres admin username" "postgres")
POSTGRES_PASSWORD=$(ask_password "Postgres admin password")
POSTGRES_DATA_DIR="${POSTGRES_DIR}/data"

echo
echo "Configuration Summary"
echo "---------------------"
echo "Directory : ${POSTGRES_DIR}"
echo "Data dir  : ${POSTGRES_DATA_DIR}"
echo "Port      : ${POSTGRES_PORT}"
echo "User      : ${POSTGRES_USER}"
echo

ask_yes_no "Continue installation?" || exit 0

success


step "Initializing postgres"

if [[ -f "${POSTGRES_DIR}/docker-compose.yml" ]]; then

    warning "Existing Postgres installation detected in ${POSTGRES_DIR}"

    ask_yes_no "Overwrite configuration?" || exit 0

fi

info "Creating ${POSTGRES_DIR}"
run mkdir -p "${POSTGRES_DIR}"

info "Creating ${POSTGRES_DATA_DIR}"
run mkdir -p "${POSTGRES_DATA_DIR}"

info "Generating temporary init compose file"

COMPOSE_INIT_FILE="${POSTGRES_DIR}/docker-compose.init.yml"

cat > "${COMPOSE_INIT_FILE}" <<EOF
services:
  postgres:
    image: postgres:18
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped

    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

    ports:
      - "${POSTGRES_PORT}:5432"

    volumes:
      - ${POSTGRES_DATA_DIR}:/var/lib/postgresql

    shm_size: 256mb

    networks:
      - marketplace

networks:
  marketplace:
    external: true
EOF


cleanup() {
  if [[ -f "${COMPOSE_INIT_FILE}" ]]; then
    step "Removing temporary files"
    rm -f "${COMPOSE_INIT_FILE}"
    success
  fi
}

trap cleanup EXIT

info "Starting init container"
run docker compose -f "${COMPOSE_INIT_FILE}" up -d

info "Waiting PostgreSQL..."

wait_container_running "${CONTAINER_NAME}"

READY=0
for i in {1..60}; do
  if docker exec "${CONTAINER_NAME}" pg_isready -U "${POSTGRES_USER}" -d postgres >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 2
done

if [[ "${READY}" -ne 1 ]]; then

  echo "Container logs:"
  docker logs --tail 100 "${CONTAINER_NAME}" || true
  echo
  error "PostgreSQL not ready"
  exit 1
fi

success


step "Generating configuration"

info "Generating docker-compose.yml"

cat > "${POSTGRES_DIR}/docker-compose.yml" <<EOF
services:
  postgres:
    image: postgres:18
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped

    ports:
      - "${POSTGRES_PORT}:5432"

    volumes:
      - ${POSTGRES_DATA_DIR}:/var/lib/postgresql

    shm_size: 256mb

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d postgres"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s

    networks:
      - marketplace

networks:
  marketplace:
    external: true
EOF

success


step "Starting Postgres"

info "Stopping init container"
run docker compose -f "${COMPOSE_INIT_FILE}" down

info "Starting Postgres"
run docker compose -f "${POSTGRES_DIR}/docker-compose.yml" up -d

info "Configuring firewall"
if ! command -v firewall-cmd >/dev/null; then
    warning "firewalld is not installed (firewall-cmd not found)."
    warning "Port ${POSTGRES_PORT} was NOT opened automatically."
    warning "Open it manually if required."
else
    info "Opening port ${POSTGRES_PORT}/tcp"
    run firewall-cmd --permanent --add-port=${POSTGRES_PORT}/tcp
    run firewall-cmd --reload
fi

info "Waiting for Postgres startup"
wait_container_healthy "${CONTAINER_NAME}"

success


step "Postgres installed"

info "Каталог установки:"
echo "${POSTGRES_DIR}"

info "Контейнер:"
echo "${CONTAINER_NAME}"

info "Пользователь БД:"
echo "${POSTGRES_USER}"

info "Порт:"
echo "${POSTGRES_PORT}"

echo
echo "Подключение из контейнера:"
echo "  docker exec -it ${CONTAINER_NAME} psql -U ${POSTGRES_USER} -d postgres"
echo
echo "Подключение с хоста:"
echo "  psql -h 127.0.0.1 -p ${POSTGRES_PORT} -U ${POSTGRES_USER} -d postgres -W"


footer