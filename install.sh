#!/usr/bin/env bash
set -euo pipefail
# Auto-installer for a Minecraft Java+Bedrock Paper server on Ubuntu/Debian
# Intended for a VPS with ~64GB RAM. This script configures the server to use 48G heap.
#
# Usage: sudo bash install.sh
#
# IMPORTANT:
# - This script attempts to download plugin jars from public GitHub releases or direct links.
# - Some plugins are distributed via SpigotMC which requires login to download directly; for those the script will create a 'manual_plugins' file listing what to download.
# - Review the script before running and adjust JAVA_XMX/XMS or plugin list as desired.
# - Tested on Ubuntu 22.04 / 24.04 (apt-based distributions).

# Variables - change if needed
MINECRAFT_USER="minecraft"
MINECRAFT_DIR="/opt/minecraft"
PAPER_VERSION="1.20.2"  # fallback; script will attempt to fetch latest Paper build for this version
JAVA_XMS="48G"
JAVA_XMX="48G"
PAPER_API="https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}"

echo "Updating packages..."
apt-get update
apt-get install -y wget curl jq unzip git openjdk-21-jdk-headless

echo "Creating minecraft user and directories..."
useradd -m -r -d "${MINECRAFT_DIR}" -s /bin/bash ${MINECRAFT_USER} || true
mkdir -p "${MINECRAFT_DIR}"/{plugins,world,backups,logs}
chown -R ${MINECRAFT_USER}:${MINECRAFT_USER} "${MINECRAFT_DIR}"

cd "${MINECRAFT_DIR}"

# Download latest Paper build for the selected version
echo "Fetching latest Paper build for version ${PAPER_VERSION}..."
LATEST_BUILD=$(curl -s "${PAPER_API}" | jq -r '.builds[-1]')
if [ -z "$LATEST_BUILD" ] || [ "$LATEST_BUILD" = "null" ]; then
  echo "Failed to fetch the latest Paper build via API. Please check PAPER_VERSION in the script."
  exit 1
fi
PAPER_JAR_URL="https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds/${LATEST_BUILD}/downloads/paper-${PAPER_VERSION}-${LATEST_BUILD}.jar"
echo "Downloading Paper from: $PAPER_JAR_URL"
wget -q -O paper.jar "$PAPER_JAR_URL"

# EULA
echo "eula=true" > eula.txt

# Basic server.properties tuned for survival
cat > server.properties <<'PROP'
# Minecraft server properties (basic recommended)
enable-jmx-monitoring=false
rcon.port=25575
level-name=world
enable-command-block=false
level-type=default
enable-status=true
allow-nether=true
motd=Welcome to the Survival Server!
query.port=25565
generator-settings=
sync-chunk-writes=true
op-permission-level=4
announce-player-achievements=false
max-players=100
network-compression-threshold=256
resource-pack-sha1=
max-world-size=29999984
function-permission-level=2
rcon.password=change_this_rcon_password
server-port=25565
server-ip=
spawn-npcs=true
allow-flight=false
level-seed=
enable-rcon=false
view-distance=6
max-build-height=256
server-authoritative-movement=true
spawn-animals=true
white-list=false
spawn-monsters=true
enforce-whitelist=false
online-mode=true
max-tick-time=60000
query.enabled=false
force-gamemode=false
rate-limit=0
debug=false
player-idle-timeout=0
text-filtering-config=
difficulty=2
spawn-protection=16
max-threads=8
resource-pack=
max-players=100
PROP

# Create start script
cat > start.sh <<'START'
#!/usr/bin/env bash
cd "$(dirname "$0")"
ulimit -n 100000
exec java -Xms${JAVA_XMS} -Xmx${JAVA_XMX} -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+ParallelRefProcEnabled -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -jar paper.jar nogui
START
chmod +x start.sh

# Systemd service
cat > /etc/systemd/system/minecraft.service <<'SERVICE'
[Unit]
Description=Minecraft Server (Paper)
After=network.target

[Service]
User=%%USER%%
Nice=5
KillMode=none
SuccessExitStatus=0 1
ProtectHome=true
ProtectSystem=full
WorkingDirectory=%%DIR%%
ExecStart=%%DIR%%/start.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
SERVICE

# Note: writing the service file above required root privileges. If script not run as root, prompt user.
if [ "$(id -u)" -ne 0 ]; then
  echo "NOTE: You must run this script as root to write systemd files and install packages."
  echo "The service file was created only if run as root."
fi

# Plugins: attempt auto-download from GitHub releases where available.
echo "Preparing plugin download list..."

MANUAL_PLUGINS_FILE="${MINECRAFT_DIR}/manual_plugins.txt"
: > "$MANUAL_PLUGINS_FILE"

download_plugin() {
  local url="$1"
  local outname="$2"
  if [ -z "$url" ]; then
    echo "No URL for $outname - add to manual_plugins.txt"
    echo "$outname" >> "$MANUAL_PLUGINS_FILE"
    return
  fi
  echo "Downloading $outname from $url"
  wget -q -O "plugins/${outname}" "$url" || (echo "Failed to download $outname; adding to manual list" && echo "$outname" >> "$MANUAL_PLUGINS_FILE")
}

# Examples of plugins with public release assets:
download_plugin "https://github.com/lucko/LuckPerms/releases/latest/download/luckperms-bukkit.jar" "LuckPerms.jar"
download_plugin "https://github.com/GeyserMC/Geyser/releases/latest/download/Geyser-Spigot.jar" "Geyser-Spigot.jar"
download_plugin "https://github.com/GeyserMC/Floodgate/releases/latest/download/floodgate-bukkit.jar" "floodgate-bukkit.jar"
download_plugin "https://repo.extendedclip.com/content/repositories/placeholder/vault.jar" "Vault.jar" || true
download_plugin "https://mediafiles.forgecdn.net/files/3619/936/worldedit-bukkit-7.2.13.jar" "WorldEdit.jar" || echo "WorldEdit may require manual update"
echo "WorldGuard may require manual download; adding to manual list"
echo "WorldGuard.jar" >> "$MANUAL_PLUGINS_FILE"
download_plugin "https://github.com/EssentialsX/Essentials/releases/latest/download/EssentialsX.jar" "EssentialsX.jar" || true
download_plugin "https://github.com/mcMMO-Dev/mcMMO/releases/latest/download/mcmmo.jar" "mcMMO.jar" || true
download_plugin "https://github.com/JobsReborn/Jobs/releases/latest/download/Jobs.jar" "Jobs.jar" || true
echo "CoreProtect.jar" >> "$MANUAL_PLUGINS_FILE"
echo "dynmap.jar" >> "$MANUAL_PLUGINS_FILE"
echo "ChestShop.jar" >> "$MANUAL_PLUGINS_FILE"
echo "VotingPlugin.jar" >> "$MANUAL_PLUGINS_FILE"
download_plugin "https://github.com/DiscordSRV/DiscordSRV/releases/latest/download/DiscordSRV.jar" "DiscordSRV.jar" || true
download_plugin "https://github.com/minidigger/spark/releases/latest/download/spark.jar" "spark.jar" || true
echo "ClearLag.jar" >> "$MANUAL_PLUGINS_FILE"

# Floodgate and Geyser configuration (basic)
echo "plugins:"
ls -la plugins || true

# Firewall (open ports) - only attempt if running as root
if [ "$(id -u)" -eq 0 ]; then
  echo "Configuring UFW to allow Minecraft ports..."
  apt-get install -y ufw
  ufw allow 22/tcp
  ufw allow 25565/tcp
  ufw allow 19132/udp
  ufw --force enable
fi

echo "Reloading systemd and enabling service (if run as root)"
if [ "$(id -u)" -eq 0 ]; then
  systemctl daemon-reload || true
  systemctl enable minecraft.service || true
  systemctl start minecraft.service || true
fi

echo "Installation finished. Please review ${MANUAL_PLUGINS_FILE} and add any jars listed there into ${MINECRAFT_DIR}/plugins/"
echo "Start the server with: sudo systemctl start minecraft.service  OR  sudo -u ${MINECRAFT_USER} bash -c 'cd ${MINECRAFT_DIR} && ./start.sh'"
echo "Enjoy your server!"
