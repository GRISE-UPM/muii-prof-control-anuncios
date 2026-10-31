#!/bin/bash

# Crea el User Pool de Cognito, su App Client, el grupo y el usuario de prueba.
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

AWS_REGION="$(aws configure get region)"

# TODO: Escribe en los comandos el nombre del User Pool y el del App Client (los indica el enunciado).
# La IP pública de la instancia, en las URL de retorno y de cierre de sesión, la escribió ec2.sh.
PUBLIC_IP=$(grep INSTANCE_IP "$PROJECT_ROOT/entrega.txt" | cut -d'=' -f2 | tr -d ' ')
POOL_NAME="anuncios-pool"
echo -n "Creando User Pool... " 
USER_POOL_ID=$(aws cognito-idp create-user-pool \
    --pool-name "$POOL_NAME" \
    --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":false}}' \
    --query "UserPool.Id" \
    --output text)
echo "listo."

# Dominio del Hosted UI (la página de inicio de sesión de Cognito). Debe ser único en la región.
echo -n "Creando el dominio del Hosted UI... "
aws cognito-idp create-user-pool-domain \
    --domain "anuncios-$EXAM_ID" \
    --user-pool-id "$USER_POOL_ID" \
    --output text >/dev/null
echo "listo."

echo -n "Creando App Client... "
# --no-generate-secret: cliente público, el secreto quedaría visible en el navegador.
# El cliente inicia sesión con usuario y contraseña directamente contra Cognito (USER_PASSWORD_AUTH)
# y puede renovar el token (refresh).
CLIENT_NAME="anuncios-front"
CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id "$USER_POOL_ID" \
    --client-name "$CLIENT_NAME" \
    --no-generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --allowed-o-auth-flows code \
    --allowed-o-auth-scopes openid \
    --allowed-o-auth-flows-user-pool-client \
    --callback-urls "https://52.54.101.194/callback" "https://$PUBLIC_IP" \
    --logout-urls "https://52.54.101.194/logout" \
    --supported-identity-providers COGNITO \
    --query "UserPoolClient.ClientId" \
    --output text)
echo "listo."

echo -n "Creando el usuario '$EXAM_USER'... "
aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$EXAM_USER" \
    --message-action SUPPRESS \
    --output text >/dev/null
aws cognito-idp admin-set-user-password \
    --user-pool-id "$USER_POOL_ID" \
    --username "$EXAM_USER" \
    --password "$EXAM_USER_PASS" \
    --permanent
echo "listo."

# Solo los usuarios del grupo admin pueden publicar mensajes.
echo -n "Creando el grupo 'admin' y añadiendo al usuario... "
aws cognito-idp create-group \
    --user-pool-id "$USER_POOL_ID" \
    --group-name admin \
    --output text >/dev/null
aws cognito-idp admin-add-user-to-group \
    --user-pool-id "$USER_POOL_ID" \
    --username "$EXAM_USER" \
    --group-name admin
echo "listo."

cat > "$PROJECT_ROOT/back/src/main/resources/cognito.properties" <<CONF
# Generado por aws-scripts/cognito.sh. No editar a mano.
spring.security.oauth2.resourceserver.jwt.issuer-uri=https://cognito-idp.$AWS_REGION.amazonaws.com/$USER_POOL_ID
CONF

cat > "$PROJECT_ROOT/front/config.js" <<CONF
// Generado por aws-scripts/cognito.sh. No editar a mano.
window.COGNITO_CONFIG = { region: "$AWS_REGION", clientId: "$CLIENT_ID", domain: "anuncios-$EXAM_ID" };
CONF

echo "Configuración de Cognito finalizada."
