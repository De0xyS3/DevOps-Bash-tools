#!/bin/bash

# Actualizar la lista de paquetes e instalar ntp
sudo apt update
sudo apt install ntp -y

# Configurar la zona horaria de Sudamérica (Perú)
sudo timedatectl set-timezone America/Lima

# Hacer una copia de seguridad del archivo de configuración original
sudo cp /etc/ntp.conf /etc/ntp.conf.bak

# Editar el archivo de configuración de NTP para agregar el servidor de tiempo de pe.pool.ntp.org
sudo sed -i 's/pool 0.ubuntu.pool.ntp.org iburst/pool pe.pool.ntp.org iburst/g' /etc/ntp.conf

# Verificar si el firewall está activado y si el puerto 123 UDP está abierto
if sudo ufw status | grep -q "Status: active"; then
  if sudo ufw status | grep -q "123/udp"; then
    echo "El puerto 123 UDP ya está abierto en el firewall."
  else
    echo "Abriendo el puerto 123 UDP en el firewall..."
    sudo ufw allow 123/udp
  fi
else
  echo "El firewall está desactivado. No es necesario abrir el puerto 123 UDP."
fi

# Reiniciar el servicio de NTP para que los cambios surtan efecto
sudo systemctl restart ntp

# Verificar que el servidor NTP está sincronizado
sudo ntpq -p
