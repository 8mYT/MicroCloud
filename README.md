Minecraft 64GB VPS Auto-Setup (Java + Bedrock Crossplay)

What this ZIP contains:
- install.sh : Main installer script. Run as root (sudo) on a fresh Ubuntu/Debian server.
- server.properties : sample file (installer writes a tuned version).
- eula.txt : eula=true so Paper will start automatically after install.
- plugins/ : empty folder; the installer will attempt to download many plugin jars into this folder.
- manual_plugins.txt : created by the installer if some plugins need manual download (SpigotMC distribution).

How to use:
1. Upload this ZIP contents to your VPS and unzip, or transfer the zip and extract:
   unzip minecraft_64gb_server.zip -d /opt/
2. Run the installer as root:
   sudo bash install.sh
3. After the script finishes, check /opt/minecraft/plugins/ and place any jars listed in manual_plugins.txt.
4. Start the server: sudo systemctl start minecraft.service
5. View logs: journalctl -u minecraft.service -f  OR  tail -f /opt/minecraft/logs/latest.log

Notes & Recommendations:
- The script sets the server heap to 48G. Change JAVA_XMS/JAVA_XMX at the top of install.sh if you need different memory allocation.
- Many popular plugins are distributed via SpigotMC (which restricts direct downloads). Those will be listed in manual_plugins.txt for you to download and upload manually.
- For Geyser/Floodgate to work for Bedrock players, you will need to configure Floodgate and optionally set up a proxy or Bungee/Velocity if you plan to use a proxy network.
- Always secure your VPS: change default passwords, configure firewall rules, and keep backups of your world folder.
