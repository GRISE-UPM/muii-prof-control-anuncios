#!/bin/bash

# Crea la instancia EC2, su IP pública estática y su grupo de seguridad.
# Termina en el primer comando que falle y muestra el error de ese comando.
set -e

PROJECT_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"

if [ ! -f "$PROJECT_ROOT/params.txt" ]; then
    echo "Error: falta params.txt. Ejecuta antes: bash params.sh <EXAM_ID>" >&2
    exit 1
fi

# Valores del examen. params.sh los escribe en params.txt.
set -a
source "$PROJECT_ROOT/params.txt"
set +a

echo -n "Creando el grupo de seguridad... "
SG_ID=$(aws ec2 create-security-group \
    --group-name anuncios-sg \
    --description "Aplicacion de anuncios" \
    --query "GroupId" \
    --output text)
echo "listo."

echo -n "Creando regla de acceso (ssh)... "
# SSH (puerto 22) solo desde la IP pública de esta máquina, con CIDR /32. params.sh la guarda en params.txt (STUDENT_IP).
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$STUDENT_IP/32" \
    --output text >/dev/null
echo "listo."

echo -n "Creando regla de acceso (https)... "
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --output text >/dev/null
echo "listo."

echo -n "Creando regla de acceso (TCP)... "
aws ec2 authorize-security-group-ingress \
    --group-name "$SG_ID"\
    --protocol tcp \
    --port 8090 \
    --cidr 0.0.0.0/0 \
    --output text >/dev/null
echo "listo."

echo -n "Creando la instancia (pendiente de aprovisionamiento)... "
# Ubuntu Server 26.04 LTS (x86_64, HVM, SSD gp3), tipo t2.micro y perfil de instancia del laboratorio.
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ami-0b6d9d3d33ba97d99 \
    --count 1 \
    --instance-type t2.micro \
    --key-name vockey \
    --iam-instance-profile Name=LabInstanceProfile \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=anuncios-ec2}]" \
    --query "Instances[0].InstanceId" \
    --output text)
echo "listo."

echo -n "Esperando a que la instancia esté lista... "
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "listo."

echo -n "Asignando la IP pública a la instancia... "
ALLOCATION_ID=$(aws ec2 allocate-address \
    --query "AllocationId" \
    --output text)
echo "listo."

echo -n "Asociando la IP pública a la instancia... "
aws ec2 associate-address \
    --instance-id "$INSTANCE_ID" \
    --allocation-id "$ALLOCATION_ID" \
    --output text >/dev/null
echo "listo."

echo -n "Esperando a que la IP pública esté asignada... "
sleep 45
echo "listo."

INSTANCE_IP=$(aws ec2 describe-addresses --allocation-ids "$ALLOCATION_ID" --query "Addresses[0].PublicIp" --output text)
sed "s/^INSTANCE_IP=.*/INSTANCE_IP=$INSTANCE_IP/" "$PROJECT_ROOT/entrega.txt" > "$PROJECT_ROOT/entrega.txt.tmp"
mv "$PROJECT_ROOT/entrega.txt.tmp" "$PROJECT_ROOT/entrega.txt"
echo "IP pública de la instancia escrita en entrega.txt."

# La IP también se escribe en cognito.sh (URL de retorno y de cierre de sesión), para que no haya que copiarla.
sed "s/<ip de la instancia>/$INSTANCE_IP/g" "$PROJECT_ROOT/aws-scripts/cognito.sh" > "$PROJECT_ROOT/aws-scripts/cognito.sh.tmp"
cat "$PROJECT_ROOT/aws-scripts/cognito.sh.tmp" > "$PROJECT_ROOT/aws-scripts/cognito.sh"
rm -f "$PROJECT_ROOT/aws-scripts/cognito.sh.tmp"
echo "IP pública de la instancia escrita en cognito.sh."

echo "ec2.sh terminado."