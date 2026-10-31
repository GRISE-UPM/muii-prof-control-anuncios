#!/bin/bash

# Introduce un fallo en tu despliegue. Averigua qué se ha roto y repáralo.
# El fallo depende de tu EXAM_ID. Deja una marca en sabotaje.txt, que debe ir en tu pull request.
set -e

PROJECT_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"

if [ ! -f "$PROJECT_ROOT/params.txt" ]; then
    echo "Error: falta params.txt. Ejecuta antes: bash params.sh <EXAM_ID>" >&2
    exit 1
fi

KEY_PATH="$PROJECT_ROOT/ssh-key/labsuser.pem"
if [ ! -f "$KEY_PATH" ]; then
    echo "Error: No se encontró la clave SSH en: $KEY_PATH" >&2
    exit 1
fi

# Valores del examen. params.sh los escribe en params.txt y ec2.sh escribe la IP de la instancia en entrega.txt.
set -a
source "$PROJECT_ROOT/params.txt"
set +a
INSTANCE_IP="$(sed -n 's/^INSTANCE_IP=//p' "$PROJECT_ROOT/entrega.txt" 2>/dev/null | head -n 1 | tr -d '[:space:]')"

source "$PROJECT_ROOT/params.sh"
_v=$(variante_sabotaje "$EXAM_ID")
_f=(
    "X009JChoYXNoX2NvcnRvICJtYXJjYTokRVhBTV9JRDowOmNlNGI1NjBkMjlhNzU1NzQiIDEyKSAmJiBzc2ggLW8gU3RyaWN0SG9zdEtleUNoZWNraW5nPW5vIC1vIExvZ0xldmVsPUVSUk9SIC1pICIkS0VZX1BBVEgiIHVidW50dUAiJElOU1RBTkNFX0lQIiAic3VkbyBzZWQgLWkgJ3MjXkVudmlyb25tZW50PVNFQ1JFVF9OQU1FPS4qI0Vudmlyb25tZW50PVNFQ1JFVF9OQU1FPXByb2QvYW51bmNpb3MvWFhYIycgL2V0Yy9zeXN0ZW1kL3N5c3RlbS9hbnVuY2lvcy5zZXJ2aWNlICYmIHN1ZG8gc3lzdGVtY3RsIGRhZW1vbi1yZWxvYWQgJiYgc3VkbyBzeXN0ZW1jdGwgcmVzdGFydCBhbnVuY2lvcyAmJiBwcmludGYgJyVzJyAnJF9NJyB8IHN1ZG8gdGVlIC92YXIvd3d3L2h0bWwvLnNhYm90YWplID4vZGV2L251bGwiICYmIHsgZWNobyAiRkVDSEE9JChkYXRlIC11ICslWS0lbS0lZFQlSDolTTolU1opIjsgZWNobyAiTUFSQ0E9JF9NIjsgfSA+ICIkUFJPSkVDVF9ST09UL3NhYm90YWplLnR4dCI="
    "X009JChoYXNoX2NvcnRvICJtYXJjYTokRVhBTV9JRDoxOmNlNGI1NjBkMjlhNzU1NzQiIDEyKSAmJiBfUD0iJChhd3MgY29nbml0by1pZHAgbGlzdC11c2VyLXBvb2xzIC0tbWF4LXJlc3VsdHMgNjAgLS1xdWVyeSAiVXNlclBvb2xzWz9OYW1lPT0nYW51bmNpb3MtcG9vbCddLklkIHwgWzBdIiAtLW91dHB1dCB0ZXh0KSIgJiYgX0M9JChhd3MgY29nbml0by1pZHAgbGlzdC11c2VyLXBvb2wtY2xpZW50cyAtLXVzZXItcG9vbC1pZCAiJF9QIiAtLXF1ZXJ5ICJVc2VyUG9vbENsaWVudHNbMF0uQ2xpZW50SWQiIC0tb3V0cHV0IHRleHQpICYmIGF3cyBjb2duaXRvLWlkcCBjcmVhdGUtdXNlci1wb29sLWNsaWVudCAtLXVzZXItcG9vbC1pZCAiJF9QIiAtLWNsaWVudC1uYW1lIGFudW5jaW9zLWZyb250IC0tbm8tZ2VuZXJhdGUtc2VjcmV0IC0tZXhwbGljaXQtYXV0aC1mbG93cyBBTExPV19VU0VSX1BBU1NXT1JEX0FVVEggQUxMT1dfUkVGUkVTSF9UT0tFTl9BVVRIIC0tYWxsb3dlZC1vLWF1dGgtZmxvd3MgY29kZSAtLWFsbG93ZWQtby1hdXRoLXNjb3BlcyBvcGVuaWQgLS1hbGxvd2VkLW8tYXV0aC1mbG93cy11c2VyLXBvb2wtY2xpZW50IC0tY2FsbGJhY2stdXJscyAiaHR0cHM6Ly8kSU5TVEFOQ0VfSVAvIiAtLWxvZ291dC11cmxzICJodHRwczovLyRJTlNUQU5DRV9JUC8iIC0tc3VwcG9ydGVkLWlkZW50aXR5LXByb3ZpZGVycyBDT0dOSVRPIC0tb3V0cHV0IHRleHQgPi9kZXYvbnVsbCAmJiBhd3MgY29nbml0by1pZHAgZGVsZXRlLXVzZXItcG9vbC1jbGllbnQgLS11c2VyLXBvb2wtaWQgIiRfUCIgLS1jbGllbnQtaWQgIiRfQyIgJiYgc3NoIC1vIFN0cmljdEhvc3RLZXlDaGVja2luZz1ubyAtbyBMb2dMZXZlbD1FUlJPUiAtaSAiJEtFWV9QQVRIIiB1YnVudHVAIiRJTlNUQU5DRV9JUCIgInByaW50ZiAnJXMnICckX00nIHwgc3VkbyB0ZWUgL3Zhci93d3cvaHRtbC8uc2Fib3RhamUgPi9kZXYvbnVsbCIgJiYgeyBlY2hvICJGRUNIQT0kKGRhdGUgLXUgKyVZLSVtLSVkVCVIOiVNOiVTWikiOyBlY2hvICJNQVJDQT0kX00iOyB9ID4gIiRQUk9KRUNUX1JPT1Qvc2Fib3RhamUudHh0Ig=="
    "X009JChoYXNoX2NvcnRvICJtYXJjYTokRVhBTV9JRDoyOmNlNGI1NjBkMjlhNzU1NzQiIDEyKSAmJiBfST0kKGF3cyBlYzIgZGVzY3JpYmUtaW5zdGFuY2VzIC0tZmlsdGVycyBOYW1lPXRhZzpOYW1lLFZhbHVlcz1hbnVuY2lvcy1lYzIgTmFtZT1pbnN0YW5jZS1zdGF0ZS1uYW1lLFZhbHVlcz1ydW5uaW5nIC0tcXVlcnkgIlJlc2VydmF0aW9uc1swXS5JbnN0YW5jZXNbMF0uSW5zdGFuY2VJZCIgLS1vdXRwdXQgdGV4dCkgJiYgX0E9JChhd3MgZWMyIGRlc2NyaWJlLWlhbS1pbnN0YW5jZS1wcm9maWxlLWFzc29jaWF0aW9ucyAtLWZpbHRlcnMgTmFtZT1pbnN0YW5jZS1pZCxWYWx1ZXM9IiRfSSIgLS1xdWVyeSAiSWFtSW5zdGFuY2VQcm9maWxlQXNzb2NpYXRpb25zWzBdLkFzc29jaWF0aW9uSWQiIC0tb3V0cHV0IHRleHQpICYmIGF3cyBlYzIgZGlzYXNzb2NpYXRlLWlhbS1pbnN0YW5jZS1wcm9maWxlIC0tYXNzb2NpYXRpb24taWQgIiRfQSIgLS1vdXRwdXQgdGV4dCAmJiBzbGVlcCA0NSAmJiBzc2ggLW8gU3RyaWN0SG9zdEtleUNoZWNraW5nPW5vIC1pICIkS0VZX1BBVEgiIHVidW50dUAiJElOU1RBTkNFX0lQIiAic3VkbyBzeXN0ZW1jdGwgcmVzdGFydCBhbnVuY2lvcyIgJiYgc3NoIC1vIFN0cmljdEhvc3RLZXlDaGVja2luZz1ubyAtbyBMb2dMZXZlbD1FUlJPUiAtaSAiJEtFWV9QQVRIIiB1YnVudHVAIiRJTlNUQU5DRV9JUCIgInByaW50ZiAnJXMnICckX00nIHwgc3VkbyB0ZWUgL3Zhci93d3cvaHRtbC8uc2Fib3RhamUgPi9kZXYvbnVsbCIgJiYgeyBlY2hvICJGRUNIQT0kKGRhdGUgLXUgKyVZLSVtLSVkVCVIOiVNOiVTWikiOyBlY2hvICJNQVJDQT0kX00iOyB9ID4gIiRQUk9KRUNUX1JPT1Qvc2Fib3RhamUudHh0Ig=="
)
# El error se clasifica para mostrar el motivo sin enseñar el texto de AWS, que nombra la operación que falló.
if ! _err="$(eval "$(printf '%s' "${_f[$_v]}" | openssl base64 -d -A)" 2>&1 >/dev/null)"; then
    if [ -z "$INSTANCE_IP" ]; then
        _motivo="falta la IP de la instancia en entrega.txt"
    elif grep -qiE 'ExpiredToken|InvalidClientTokenId|Unable to locate credentials|security token' <<< "$_err"; then
        _motivo="las credenciales de AWS han caducado o no son válidas"
    elif grep -qiE 'Could not connect|timed out|Connection refused|Permission denied' <<< "$_err"; then
        _motivo="no se pudo conectar con la instancia"
    elif grep -qiE 'None|ResourceNotFound|InvalidParameter|NotFound' <<< "$_err"; then
        _motivo="no se encuentra algún recurso del despliegue (pool, cliente o instancia)"
    else
        _motivo="causa no identificada"
    fi
    {
        echo "************************************************************************"
        echo "************************************************************************"
        echo "***  AVISO: no se ha podido introducir el fallo. AVISA AL PROFESOR.  ***"
        echo "***  No vuelvas a ejecutar sabotaje.sh hasta que te lo indique.      ***"
        echo "************************************************************************"
        echo "************************************************************************"
        echo "Motivo: $_motivo."
    } >&2
    exit 1
fi


echo "Se ha introducido un fallo en tu despliegue."
echo "Comprueba que (a) puedes iniciar sesión y publicar un mensaje y (b) la huella de whoami es la de tu secreto."
echo "Si algo falla, averigua por qué y repáralo."
echo "No olvides incluir sabotaje.txt en tu pull request."
