#!/bin/bash

# Crea el secreto con las credenciales de la base de datos H2, a partir de aws-scripts/secreto.json.
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

if [ ! -f "$PROJECT_ROOT/aws-scripts/secreto.json" ]; then
    echo "Error: falta aws-scripts/secreto.json." >&2
    exit 1
fi
# Spring Boot importa el JSON del secreto y expone cada campo como propiedad (username, password y dbname),
# que son las que usa back/src/main/resources/application.properties para el datasource.
if grep -qE '"[a-z]+"[[:space:]]*:[[:space:]]*""' "$PROJECT_ROOT/aws-scripts/secreto.json"; then
    echo "Error: aws-scripts/secreto.json tiene campos vacíos. Rellena sus valores." >&2
    exit 1
fi

echo -n "Creando el secreto... "
aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "$(cat "$PROJECT_ROOT/aws-scripts/secreto.json")" --output text >/dev/null
echo "listo."