#!/bin/bash
#0 3 * * * /root/ssl_renew_all.sh >/dev/null 2>&1
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
cd /root

for domain in $(/bin/ls /var/cpanel/users); do
  if [ -d "/home/$domain/public_html" ]; then
    echo "Renovando SSL para $domain"
    /usr/local/cpanel/letsencrypt/letsencrypt-auto certonly --renew-by-default --text --email your@email.com --agree-tos --webroot -w /home/$domain/public_html -d $domain -d www.$domain
    echo "----------------------------------------------------"
  fi
done
echo "Este es un correo de prueba" | mail -s "Correo de prueba" -S smtp=smtp.gmail.com -S smtp-use-starttls -S smtp-auth=login -S smtp-auth-user=tu_correo@gmail.com -S smtp-auth-password=tu_contraseña correo_destino@example.com

