#!/bin/bash
#showmount -e $ip
sudo apt-get install figlet &> /dev/null
echo "Comprobando si NFS está instalado..."
if ! [ -x "$(command -v nfs-kernel-server)" ]; then
  echo 'NFS no esta instalado. Instalando...'
  figlet -f slant "Instalando NFS" | pv -qL 10
    sudo apt update
    sudo apt install nfs-kernel-server
  echo "NFS ha sido instalado"
else
  echo "NFS ya está instalado."
fi
echo "Ingresa ruta que se publicara:"
read p_dir
sudo mkdir -p $p_dir
echo "Estableciendo permisos:"
sudo chown nobody:nogroup $p_dir

echo "Ingrese IP servidor:"
read server_ip

cat > /etc/exports << EOL
$p_dir  $server_ip(rw,sync,no_root_squash,no_subtree_check)

EOL
#sudo sh -c "echo '$p_dir $server_ip(rw,sync,no_root_squash,no_subtree_check)' >> /etc/exports"

echo "Reiniciando servicios:"
sudo systemctl restart nfs-kernel-server
