#!/bin/bash

# Instala Nginx en la instancia (Ubuntu). Sirve el front en / y reenvía /api/ al back en el
# puerto 8080, todo por HTTPS (443) con un certificado autofirmado. Termina en el primer comando que falle y muestra el error de ese comando.
set -e

PROJECT_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"

if [ ! -f "$PROJECT_ROOT/params.txt" ]; then
    echo "Error: falta params.txt. Ejecuta antes: bash params.sh <EXAM_ID>" >&2
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/ssh-key/labsuser.pem" ]; then
    echo "Error: No se encontró la clave SSH en: ssh-key/labsuser.pem" >&2
    exit 1
fi

echo "Configurando Nginx en la instancia..."

PUBLIC_IP=$(grep INSTANCE_IP "$PROJECT_ROOT/entrega.txt" | cut -d'=' -f2 | tr -d ' ')

echo "La IP pública de la instancia es: $PUBLIC_IP"

# -T: sin pseudo-terminal, para que no avise al leer el script por stdin
# La IP se pasa como argumento porque el heredoc está entre comillas y no expande variables localmente.
ssh -T -o StrictHostKeyChecking=no -o LogLevel=ERROR -i "$PROJECT_ROOT/ssh-key/labsuser.pem" ubuntu@"$PUBLIC_IP" bash -s -- "$PUBLIC_IP" << 'END_NGINX'
set -e
PUBLIC_IP=$1
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

# Certificado autofirmado para la IP pública (el navegador avisará de que no es de confianza).
sudo openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
    -keyout /etc/ssl/private/anuncios.key -out /etc/ssl/certs/anuncios.crt \
    -subj "/CN=$PUBLIC_IP" -addext "subjectAltName=IP:$PUBLIC_IP" 2>/dev/null \
    || { echo "Error: no se pudo generar el certificado. Revisa la IP escrita en este comando." >&2; exit 1; }

sudo tee /etc/nginx/sites-available/default > /dev/null << 'NGINX_CONF'
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    ssl_certificate /etc/ssl/certs/anuncios.crt;
    ssl_certificate_key /etc/ssl/private/anuncios.key;
    server_name _;

    root /var/www/html;
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX_CONF

sudo rm -rf /var/www/html/*
echo '<h1>Aplicación de anuncios</h1><p>Desplegando...</p>' | sudo tee /var/www/html/index.html > /dev/null
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
END_NGINX

echo "Configuración de Nginx finalizada."
