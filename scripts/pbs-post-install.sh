#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# Modified for Docker environment

# Set default values for environment variables
PBS_SOURCES=${PBS_SOURCES:-"yes"}
PBS_ENTERPRISE=${PBS_ENTERPRISE:-"yes"}
PBS_NO_SUBSCRIPTION=${PBS_NO_SUBSCRIPTION:-"yes"}
PBS_TEST=${PBS_TEST:-"no"}
DISABLE_SUBSCRIPTION_NAG=${DISABLE_SUBSCRIPTION_NAG:-"yes"}
UPDATE_PBS=${UPDATE_PBS:-"yes"}
REBOOT_PBS=${REBOOT_PBS:-"no"}

header_info() {
  clear
  cat <<"EOF"
    ____  ____ _____    ____             __     ____           __        ____
   / __ \/ __ ) ___/   / __ \____  _____/ /_   /  _/___  _____/ /_____ _/ / /
  / /_/ / __  \__ \   / /_/ / __ \/ ___/ __/   / // __ \/ ___/ __/ __ `/ / /
 / ____/ /_/ /__/ /  / ____/ /_/ (__  ) /_   _/ // / / (__  ) /_/ /_/ / / /
/_/   /_____/____/  /_/    \____/____/\__/  /___/_/ /_/____/\__/\__,_/_/_/

EOF
}

# Keep the color and message functions
RD=$(echo "\033[01;31m")
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

start_routines() {
  header_info
  VERSION="$(awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release)"

  # PBS Sources
  if [[ "${PBS_SOURCES}" == "yes" ]]; then
    msg_info "Changing to Proxmox Backup Server Sources"
    cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian ${VERSION} main contrib
deb http://deb.debian.org/debian ${VERSION}-updates main contrib
deb http://security.debian.org/debian-security ${VERSION}-security main contrib
EOF
    msg_ok "Changed to Proxmox Backup Server Sources"
  fi

  # PBS Enterprise
  if [[ "${PBS_ENTERPRISE}" == "yes" ]]; then
    msg_info "Disabling 'pbs-enterprise' repository"
    cat <<EOF >/etc/apt/sources.list.d/pbs-enterprise.list
# deb https://enterprise.proxmox.com/debian/pbs ${VERSION} pbs-enterprise
EOF
    msg_ok "Disabled 'pbs-enterprise' repository"
  fi

  # PBS No Subscription
  if [[ "${PBS_NO_SUBSCRIPTION}" == "yes" ]]; then
    msg_info "Enabling 'pbs-no-subscription' repository"
    cat <<EOF >/etc/apt/sources.list.d/pbs-install-repo.list
deb http://download.proxmox.com/debian/pbs ${VERSION} pbs-no-subscription
EOF
    msg_ok "Enabled 'pbs-no-subscription' repository"
  fi

  # PBS Test
  if [[ "${PBS_TEST}" == "yes" ]]; then
    msg_info "Adding 'pbstest' repository and set disabled"
    cat <<EOF >/etc/apt/sources.list.d/pbstest-for-beta.list
# deb http://download.proxmox.com/debian/pbs ${VERSION} pbstest
EOF
    msg_ok "Added 'pbstest' repository"
  fi

  # Subscription Nag
  if [[ "${DISABLE_SUBSCRIPTION_NAG}" == "yes" ]]; then
    msg_info "Disabling subscription nag"
    
    # Create the config first
    echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" >/etc/apt/apt.conf.d/no-nag-script
    
    # Wait for services to be fully up
    for i in {1..10}; do
      echo "Waiting for services to initialize... attempt $i"
      sleep 10
      
      # Direct modification of the JS file
      if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
        sed -i '/data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
        msg_ok "Disabled subscription nag (Delete browser cache)"
        break
      fi
      
      # Try reinstalling as a fallback
      if [ $i -eq 5 ]; then
        apt --reinstall install proxmox-widget-toolkit &>/dev/null
      fi
    done
    
    # If we couldn't find the file after all attempts
    if [ ! -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
      msg_error "Could not disable subscription nag - file not found"
    fi
  fi

  # Update PBS
  if [[ "${UPDATE_PBS}" == "yes" ]]; then
    msg_info "Updating Proxmox Backup Server (Patience)"
    apt-get update &>/dev/null
    apt-get -y dist-upgrade &>/dev/null
    msg_ok "Updated Proxmox Backup Server"
  fi

  # Reboot PBS
  if [[ "${REBOOT_PBS}" == "yes" ]]; then
    msg_info "Rebooting Proxmox Backup Server"
    sleep 2
    msg_ok "Completed Post Install Routines"
    reboot
  else
    msg_ok "Completed Post Install Routines"
  fi
}

# Check if running in PVE
if command -v pveversion >/dev/null 2>&1; then
    echo -e "\n🛑  PVE Detected, Wrong Script!\n"
    exit 1
fi

# Start the routines directly without prompting
start_routines
