#!/bin/bash

# Deriva los parámetros individuales del control a partir del EXAM_ID.
# Es determinista, así que el profesor calcula los mismos valores al corregir y no hace
# falta intercambiar secretos.
#
# Uso (genera params.txt):
#   bash params.sh <EXAM_ID>
#
# Otros scripts lo cargan con source para usar las funciones.

sha() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum
    else
        shasum -a 256
    fi | cut -d' ' -f1
}

# hash_corto <texto> <n>  -> primeros n caracteres hexadecimales del SHA-256
hash_corto() {
    printf '%s' "$1" | sha | cut -c1-"$2"
}

# huella <contraseña>  -> lo mismo que devuelve /api/whoami
huella() {
    printf '%s' "$1" | sha
}

# derivar_parametros <EXAM_ID>
derivar_parametros() {
    EXAM_ID="$1"
    EXAM_USER="admin"
    EXAM_USER_PASS="Adm-$(hash_corto "clave:$1" 8)-A1"
    SECRET_NAME="prod/anuncios/$1"
    DB_PASS="$(hash_corto "secreto:$1" 24)"
}

# variante_sabotaje <EXAM_ID>  -> 0, 1 o 2
variante_sabotaje() {
    echo $(( 16#$(hash_corto "sabotaje:$1" 2) % 3 ))
}

# Solo como script: escribe params.txt junto a este fichero.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -e
    DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
    ENV_FILE="$DIR/params.txt"

    if [ -z "${1:-}" ]; then
        echo "Uso: $0 <EXAM_ID>"
        exit 1
    fi
    if ! [[ "$1" =~ ^[A-Za-z0-9-]{3,30}$ ]]; then
        echo "Error: EXAM_ID solo admite letras, números y guiones (3 a 30 caracteres)."
        exit 1
    fi

    derivar_parametros "$1"
    # IP pública de esta máquina (la usa ec2.sh para la regla del SSH). Si no se averigua, queda vacía.
    STUDENT_IP="$(curl -s --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')"
    if ! [[ "$STUDENT_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        STUDENT_IP=""
        {
            echo "************************************************************************"
            echo "************************************************************************"
            echo "***  AVISO: no se pudo averiguar tu IP pública. AVISA AL PROFESOR.   ***"
            echo "***  No ejecutes ec2.sh hasta que te lo indique.                     ***"
            echo "************************************************************************"
            echo "************************************************************************"
        } >&2
    fi
    cat > "$ENV_FILE" <<ENV
EXAM_ID=$EXAM_ID
EXAM_USER=$EXAM_USER
EXAM_USER_PASS=$EXAM_USER_PASS
SECRET_NAME=$SECRET_NAME
DB_PASS=$DB_PASS
STUDENT_IP=$STUDENT_IP
ENV
    echo "Parámetros guardados en params.txt (no se sube al repositorio)."
    echo "  Usuario / contraseña . $EXAM_USER / $EXAM_USER_PASS"
    echo "  Nombre del secreto ... $SECRET_NAME"
    echo "  Contraseña de la BD .. $DB_PASS"
    if [ -n "$STUDENT_IP" ]; then echo "  Tu IP pública ........ detectada"; else echo "  Tu IP pública ........ no detectada"; fi

    # entrega.txt: el EXAM_ID lo escribe este script. La IP la escribe el estudiante a mano
    # (si ya estaban escritas, no se tocan).
    ENTREGA="$DIR/entrega.txt"
    if [ -f "$ENTREGA" ] && grep -q '^EXAM_ID=' "$ENTREGA"; then
        sed "s/^EXAM_ID=.*/EXAM_ID=$EXAM_ID/" "$ENTREGA" > "$ENTREGA.tmp"
        mv "$ENTREGA.tmp" "$ENTREGA"
    else
        cat > "$ENTREGA" <<ENTREGA_TXT
# EXAM_ID lo escribe bash params.sh. La IP de la instancia la escribe aws-scripts/ec2.sh.
EXAM_ID=$EXAM_ID
INSTANCE_IP=
ENTREGA_TXT
    fi
    echo "  entrega.txt .......... EXAM_ID escrito (la IP la escribe ec2.sh)"
fi
