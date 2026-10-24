# Examen práctico de arquitectura en AWS

**Duración:** 2 horas · **Modalidad:** individual, con todo el material, internet y asistentes de IA permitidos · **Entrega:** un *pull request* del *fork* del repositorio.

## La aplicación

Una aplicación de anuncios mínima, prácticamente igual a la utilizada en el simulacro de examen. Cualquier usuario autenticado puede leer anuncios, y el administrador es el único que puede publicarlos.

| Componente | Qué hace |
|---|---|
| `back/` | API en Spring Boot que corre en la instancia y sirve en el puerto **8080**. Nginx redirige las llamadas /api/* realizadas desde Internet (puerto **443**) al puerto 8080. El back proporciona `GET /api/whoami`, que informa de la identidad de usuario, el grupo y la huella de la contraseña del secreto (para no mostrar la contraseña en texto plano en Internet), y `GET` y `POST /api/mensajes`, que listan y publican mensajes. En el **8090**, el puerto de gestión, sirve `/actuator/health`. |
| `front/` | Una página estática que permite iniciar y cerrar sesión con Cognito (Hosted UI), listar mensajes y publicar. |
| `aws-scripts/` | Scripts de despliegue. Cargan sus valores de `params.txt`, excepto algunos casos: la **IP pública de la instancia** en los comandos de `back.sh`, `nginx.sh` y `front.sh`, los **nombres del *User Pool* y del *App Client*** en `cognito.sh` y los **valores del secreto** en `secreto.json`. También contienen algunos problemas que tendrás que diagnosticar y corregir. |

La arquitectura que debes dejar desplegada es esta:

```
  Navegador ──:443  (HTTPS)──▶ [ Grupo de seguridad ] ──▶ EC2 (Ubuntu)
      │                                                    ├─ Nginx  :443  sirve el front y reenvía /api/ al :8080
      │                                                    ├─ Spring :8080 /api/ (no disponible públicamente)
      │                                                    │   
      │     ──:8090 (HTTP) ──▶ [ Grupo de seguridad ] ──▶  ├─ Spring :8090 /actuator/health (público)
      │                                                    │
      │                                                    │ LabInstanceProfile
      │                                                    ▼
      ▼                                             Secrets Manager
  Cognito (User Pool + App Client + grupo + Hosted UI)
```

## Antes de empezar

Coloca la clave SSH del laboratorio en `ssh-key/labsuser.pem`, pero **NO la subas al repositorio** (ahora mismo, está listada en `.gitignore`). Ejecuta `chmod 400 ssh-key/labsuser.pem` para que `ssh` la acepte.

1. Haz un *fork* de este repositorio, y trabaja directamente en su rama `main`.
2. Tu **EXAM_ID** es un número aleatorio de 6 dígitos, que tú escoges libremente.
3. Ejecuta el script siguiente para generar una serie de parámetros individuales:

```bash
bash params.sh <EXAM_ID>
```
4. Ejecuta `aws-scripts/ec2.sh`. Debería terminar **sin errores**.

   - Crea una instancia Ubuntu Server 26.04 LTS `t2.micro`, con el perfil de instancia del laboratorio, una IP pública estática y su grupo de seguridad.
   - `ec2.sh` abre al exterior el puerto **443** (HTTPS), con regla 0.0.0.0/0
   - `ec2.sh` también abre el puerto **22** (SSH), solo se abre desde **tu IP**, con una regla `/32`.
   - Al terminar, el script escribe **la IP pública de la instancia** en `entrega.txt` (tanto para corregir el examen como para que tu la conozcas).

**Checkpoint.** Comprueba que `entrega.txt` tiene la IP de la instancia en el campo `INSTANCE_IP`, y puedes conectarte por SSH.

## Tareas (4 puntos de despliegue)

Ejecuta los scripts de `aws-scripts/` en el orden que indican las tareas.

### Tarea 1. Despliegue del back · 0,25 puntos

Completa los `TODO` de `back.sh` y ejecútalo. Debería terminar **sin errores**.

**Pregunta (0,75 puntos).** El back publica su estado de salud en el puerto de gestión 8090, pero `http://<INSTANCE_IP>:8090/actuator/health` no responde desde Internet. ¿Por qué no? Corrígelo desde la **consola web de AWS** y deja también el cambio escrito en `ec2.sh`.

Porque el grupo de seguridad actual (anuncios-sg) no tiene ninguna regla de entrada que permita el tráfico hacia el puerto 8090.

**Pregunta adicional (+1 punto).** `http://<INSTANCE_IP>:8090/actuator/health` responde aunque `nginx.sh` no se haya ejecutado. ¿Por qué se puede acceder al puerto 8090 sin Nginx?

Porque la aplicación Spring Boot está exponiendo directamente ese puerto al exterior, mientras que el puerto 8080 está bloqueado por el cortafuegos y obliga a pasar por el proxy inverso de Nginx.

### Tarea 2. Despliegue de la instancia · 0,5 puntos

Completa los `TODO` de `nginx.sh` y `front.sh` y ejecútalos en ese orden. Los dos deberían terminar **sin errores**.

Nginx atiende por HTTPS con un **certificado autofirmado**, que se genera en la propia instancia y caduca a los 30 días. Por eso, el navegador mostrará un aviso que deberás aceptar.

**Checkpoint.** Cuando los scripts terminen de ejecutarse:

- `https://<INSTANCE_IP>/api/whoami` debe responder un JSON que incluya tu `EXAM_ID`.
- `https://<INSTANCE_IP>/` debe mostrar el front.

Si algo no responde, no sigas, porque hay algo mal.

- Si recibes un `502`, Spring Boot todavía está arrancando. Espera unos segundos y reintenta.
- Si el servicio no arranca, mira el registro en la instancia con `sudo journalctl -u anuncios -n 50`.

**Pregunta (0,5 puntos).** `https://<INSTANCE_IP>/api/whoami` funciona, pero `https://<INSTANCE_IP>/api/mensajes` no. ¿Por qué?

Porque el endpoint /api/mensajes requiere autenticación, mientras que /api/whoami es un endpoint público diseñado para consultarse sin iniciar sesión.

### Tarea 3. Identidad con Cognito y Hosted UI · 1 punto

Completa los `TODO` de `aws-scripts/cognito.sh`, que piden escribir en los comandos el nombre del *User Pool* y el del *App Client*, y ejecútalo.

| Valor | Cuál es |
|---|---|
| Nombre del *User Pool* | `anuncios-pool` |
| Nombre del *App Client* | `anuncios-front` |

El script crea además el dominio del **Hosted UI** (la página de inicio de sesión de Cognito), registra las URL de retorno y de cierre de sesión (con la IP de la instancia, que `ec2.sh` ya escribió en el script), crea el grupo `admin` y el usuario del examen, y asigna el usuario al grupo `admin`.

El script genera `back/src/main/resources/cognito.properties` y `front/config.js`. Vuelve a ejecutar `back.sh` y `front.sh` para que el back y el front recojan la configuración de Cognito.

Cognito compara las URL de retorno y de cierre de sesión **carácter a carácter** con la que le envía el front, barra final incluida. Si tienes que volver a crear el *User Pool* y su dominio, el Hosted UI de Cognito puede tardar **uno o dos minutos** en responder bien (mientras tanto da errores como «Client does not exist»).

**Checkpoint.**

1. Obtén un *access token* por línea de comandos, sustituyendo los tres valores entre `<...>` (`EXAM_USER` y `EXAM_USER_PASS` están en `params.txt`, y el `client id` en `front/config.js`):

   ```bash
   aws cognito-idp initiate-auth \
     --client-id <CLIENT_ID> \
     --auth-flow USER_PASSWORD_AUTH \
     --auth-parameters USERNAME=<EXAM_USER>,PASSWORD=<EXAM_USER_PASS> \
     --query 'AuthenticationResult.AccessToken' \
     --output text
   ```

2. Llama al back con dicho token:

   ```bash
   curl -sk -H "Authorization: Bearer <TOKEN>" https://<INSTANCE_IP>/api/whoami
   ```

El campo `usuario` debe mostrar tu usuario. Si no es así, no sigas porque hay algo mal.

**Pregunta (1,5 puntos).** Abre `https://<INSTANCE_IP>/` y pulsa **Entrar con Cognito**. El Hosted UI muestra un error en lugar de pedirte el usuario y la contraseña. ¿Por qué falla? Cognito solo redirige a direcciones registradas de antemano en el cliente de la aplicación: explica por qué existe esa restricción. Corrige este problema en `cognito.sh` y despliega correctamente.

Entiendo que falla porque está registrada en el script como /callback y se accede como /callback/. 

### Tarea 4. Secretos · 0,75 puntos

Rellena `aws-scripts/secreto.json` y ejecuta `aws-scripts/secrets.sh`, que crea con él un secreto en Secrets Manager. Después, vuelve a ejecutar `back.sh` para que el back lea el secreto.

- `secreto.json` tiene el formato, pero no los valores del secreto. Los campos son los que espera `back/src/main/resources/application.properties` para conectarse a la base de datos. La contraseña (`DB_PASS`) está en `params.txt`. El usuario y el nombre de la base de datos los eliges tú.
- El **nombre del secreto** (`SECRET_NAME`) también está en `params.txt`. El script lo lee de ahí.

`GET /api/whoami` devuelve en `huella` el SHA-256 de la contraseña que la aplicación ha leído de tu secreto. Si no existe secreto, devuelve el SHA-256 de una cadena vacía, que es `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

**Checkpoint.** Calcula la huella de tu contraseña y compárala con la que devuelve la aplicación. Las dos deben ser iguales.

```bash
curl -sk https://<INSTANCE_IP>/api/whoami

# En macOS
printf '%s' "<DB_PASS>" | shasum -a 256

# En Linux, WSL o Git Bash (Windows)
printf '%s' "<DB_PASS>" | sha256sum
```

(`printf '%s'` evita añadir un salto de línea, que cambiaría el resultado.)

**Pregunta (0,75 puntos).** `GET /api/whoami` indica que la sesión no está iniciada (el usuario es `null`) pero, aun así, la aplicación consigue leer el secreto de Secrets Manager. ¿Cuál es la razon? ¿Se trata de un error?

La aplicación backend obtiene acceso a AWS Secrets Manager gracias al Perfil de Instancia que se le asigna a la máquina EC2 durante su creación, y no mediante las credenciales del usuario final en Cognito.

No es un error.    El servidor necesita leer las credenciales para conectarse a la base de datos al arrancar, independientemente de que haya usuarios conectados a la web o no.
### Tarea 5. Fallo sembrado · 1,25 puntos

**No empieces esta tarea hasta haber terminado las cuatro anteriores.** Si algo de lo anterior no funciona, no podrás distinguir tu error del fallo sembrado.

Ejecuta `aws-scripts/sabotaje.sh`, **una sola vez**. El script introduce **un fallo en tu despliegue** que depende de tu EXAM_ID y **no te dice cuál es**. Tu trabajo es averiguar qué se ha roto y repararlo. Al terminar, el script escribe `sabotaje.txt`, que **SÍ SE ENTREGA**.

**Checkpoint.** Cuando hayas reparado el fallo, comprueba las dos cosas que el propio script te recuerda.

- Puedes iniciar sesión en el front con el usuario del examen y publicar un mensaje.
- La `huella` de `whoami` es la de tu contraseña (la de `DB_PASS`).

Si algo de esto falla, tu solución no es correcta.

**Pregunta (1,5 puntos).** Describe qué se había roto, cómo lo detectaste (qué síntoma viste y qué pruebas hiciste para localizar la causa) y cómo lo reparaste.

El script de sabotaje eliminaba el App Client original asociado al grupo de usuarios de Cognito e inyectaba de forma automatizada uno nuevo con un identificador (client_id) diferente.

Lo detecté al intentar iniciar sesión en la aplicación web, Cognito bloqueaba el acceso mostrando un error en pantalla. Utilizando las herramientas de desarrollador del navegador , en la petición de redirección el id de cliente no coincidía.

Para repararlo modifiqué el id de cliente en config.js.

### Tarea 6. Terminar examen · 0,25 puntos

Para terminar, cierra la sesión de la aplicación.

**Checkpoint.** Abre `https://<INSTANCE_IP>/`, inicia sesión con el usuario del examen y pulsa **Salir**. Debes volver al front, sin sesión iniciada.

**Pregunta (1 punto).** Al pulsar **Salir**, Cognito muestra una página de error en lugar de volver al front. ¿Por qué? ¿Por qué no se corrigió al arreglar el inicio de sesión? Corrige este problema en `cognito.sh` y despliega correctamente.

Cognito valida estrictamente que la ruta de destino posterior al cierre de sesión esté incluida en la lista blanca de Logout URLs del cliente. Antes se corrigió la url de callback pero no la de logout. Para solucionarlo de forma permanente, es necesario declarar esta url dentro del script cognito.sh y volver a aplicarlo.

## Recuerda

- No subas `params.txt` ni la clave SSH (`.pem`). Ya están en `.gitignore`.
- Mientras no se corrija, no debes borrar los componentes (ec2, grupo de seguridad, ip estática, pool de Cognito) que has creado.
- Si cambias de red durante el examen (por ejemplo, de ethernet a eduroam o de una Wi-Fi a otra), tu IP pública cambia y `ssh` dejará de conectar (se queda esperando hasta que expira). Añade tu IP nueva a la regla del puerto 22 del grupo de seguridad desde la consola web.
