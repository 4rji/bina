#!/bin/zsh

# Verifica si el usuario es root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ser ejecutado como root" 
   exit 1
fi

# Instala el servidor SSH si no está instalado
if ! dpkg -s openssh-server >/dev/null 2>&1; then
    apt-get update
    apt-get install -y openssh-server
fi

# Crea un nuevo grupo para SFTP
groupadd sftp_users

# Configura el archivo de configuración de SSH para SFTP
cat <<EOT >> /etc/ssh/sshd_config
Match Group sftp_users
ChrootDirectory %h
X11Forwarding no
AllowTcpForwarding no
ForceCommand internal-sftp
EOT

# Reinicia el servicio SSH
service ssh restart

echo "Servidor SFTP configurado exitosamente."

