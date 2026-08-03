#!/bin/bash

set -Eeuo pipefail

########################################
# Colors
########################################

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

########################################
# Header / Footer
########################################

header() {

    clear

    echo -e "${CYAN}"
    echo "============================================================"
    echo " $1"
    echo "============================================================"
    echo -e "${RESET}"

    [[ -n "${2:-}" ]] && echo "$2"

    echo
}

footer() {

    echo
    echo -e "${GREEN}"
    echo "============================================================"
    echo " Installation completed successfully"
    echo "============================================================"
    echo -e "${RESET}"
}

########################################
# Step
########################################

step() {

    echo
    echo -e "${BLUE}==>${RESET} $1"
}

info() {

    echo "    • $1"
}

success() {

    echo -e "    ${GREEN}✔ Done${RESET}"
}

warning() {

    echo -e "    ${YELLOW}⚠ $1${RESET}"
}

error() {

    echo
    echo -e "${RED}✘ ERROR:${RESET} $1"
    exit 1
}

########################################
# Input
########################################

ask() {

    local prompt="$1"
    local default="${2:-}"
    local value

    while true; do

        if [[ -n "$default" ]]; then
            read -rp "$prompt [$default]: " value
            value="${value:-$default}"
        else
            read -rp "$prompt: " value
        fi

        [[ -n "$value" ]] && {
            echo "$value"
            return
        }

        warning "Value cannot be empty."

    done
}

ask_username() {

    local prompt="$1"
    local default="${2:-}"
    local username

    while true; do

        if [[ -n "$default" ]]; then
            read -rp "$prompt [$default]: " username
            username="${username:-$default}"
        else
            read -rp "$prompt: " username
        fi

        if [[ "$username" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then

            echo "$username"
            return

        fi

        warning "Invalid username."

    done
}

ask_password() {

    local prompt="$1"
    local password

    while true; do

        read -rsp "$prompt: " password

        [[ -n "$password" ]] && {
            echo "$password"
            return
        }

        warning "Password cannot be empty."

    done
}

ask_port() {

    local prompt="$1"
    local default="$2"
    local port

    while true; do

        read -rp "$prompt [$default]: " port

        port="${port:-$default}"

        if [[ "$port" =~ ^[0-9]+$ ]] &&
           (( port >= 1 && port <= 65535 )); then

            echo "$port"
            return

        fi

        warning "Port must be between 1 and 65535."

    done
}

ask_directory() {

    local prompt="$1"
    local default="$2"
    local dir

    while true; do

        read -rp "$prompt [$default]: " dir

        dir="${dir:-$default}"

        if [[ "$dir" = /* ]]; then

            echo "$dir"
            return

        fi

        warning "Please enter an absolute path."

    done
}

ask_yes_no() {

    local prompt="$1"
    local default="${2:-Y}"
    local answer

    while true; do

        if [[ "$default" == "Y" ]]; then

            read -rp "$prompt [Y/n]: " answer
            answer="${answer:-Y}"

        else

            read -rp "$prompt [y/N]: " answer
            answer="${answer:-N}"

        fi

        case "$answer" in
            Y|y|YES|Yes|yes)
                return 0
                ;;
            N|n|NO|No|no)
                return 1
                ;;
            *)
                warning "Please answer yes or no."
                ;;
        esac

    done
}

########################################
# Execute command
########################################

run() {

    "$@" || error "Command failed: $*"
}

########################################
# Checks
########################################

check_root() {

    [[ $EUID -eq 0 ]] || error "Run this script as root."
}

check_dnf() {

    command -v dnf >/dev/null \
        || error "DNF package manager not found."
}

check_docker() {

    command -v docker >/dev/null
}

check_docker_running() {

    docker info >/dev/null 2>&1
}

check_compose() {

    docker compose version >/dev/null 2>&1
}

container_exists() {

    docker ps -a --format '{{.Names}}' | grep -Fxq "$1"
}

wait_container_running() {

    local container="$1"

    for _ in {1..30}; do

        if docker inspect \
            --format '{{.State.Running}}' \
            "$container" 2>/dev/null | grep -q true
        then
            return
        fi

        sleep 2

    done

    error "Container '$container' failed to start."
}

wait_container_healthy() {

    local container="$1"

    for _ in {1..60}; do

        status=$(docker inspect \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' \
            "$container" 2>/dev/null)

        case "$status" in

            healthy)
                return
                ;;

            unhealthy)
                docker logs "$container"
                error "Container '$container' is unhealthy."
                ;;

        esac

        sleep 2

    done

    docker logs "$container"

    error "Container '$container' did not become healthy."
}

########################################
# Docker
########################################

create_network() {

    docker network inspect marketplace >/dev/null 2>&1 \
        || docker network create marketplace >/dev/null
}