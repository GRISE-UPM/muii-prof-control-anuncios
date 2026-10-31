#!/bin/bash

# Publica el front estático en /var/www/html de la instancia (Ubuntu).
# Termina en el primer comando que falle y muestra el error de ese comando.
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

PUBLIC_IP=$(grep INSTANCE_IP "$PROJECT_ROOT/entrega.txt" | cut -d'=' -f2 | tr -d ' ')

echo -n "Subiendo el front a la instancia... "
# TODO: Escribe en cada comando (ssh, scp y ssh) la IP pública de la instancia (ec2.sh la escribió en entrega.txt).
ssh -T -o StrictHostKeyChecking=no -o LogLevel=ERROR -i "$PROJECT_ROOT/ssh-key/labsuser.pem" ubuntu@$PUBLIC_IP "rm -rf /tmp/front && mkdir /tmp/front"
scp -q -o StrictHostKeyChecking=no -i "$PROJECT_ROOT/ssh-key/labsuser.pem" "$PROJECT_ROOT/front"/* ubuntu@$PUBLIC_IP:/tmp/front/ 2>/dev/null \
    || { echo "Error: no se ha podido subir el front a la instancia." >&2; exit 1; }

ssh -T -o StrictHostKeyChecking=no -o LogLevel=ERROR -i "$PROJECT_ROOT/ssh-key/labsuser.pem" ubuntu@$PUBLIC_IP << 'ENDSSH'
set -e
sudo rm -rf /var/www/html/*
sudo mv /tmp/front/* /var/www/html/
sudo rm -rf /tmp/front
sudo chown -R www-data:www-data /var/www/html
ENDSSH
echo "listo."

echo "Despliegue del front finalizado."
