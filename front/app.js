// Front mínimo. Nginx sirve esta página y reenvía /api/ al back, así que no hace falta CORS.
// config.js lo genera cognito.sh con la región, el ClientId del User Pool y el dominio del Hosted UI.
let accessToken = null;

const $ = (id) => document.getElementById(id);

async function cargar() {
  // Los mensajes requieren un access token: sin sesión no se piden.
  if (!accessToken) {
    $('lista').innerHTML = '<li>Inicia sesión para ver los mensajes.</li>';
    return;
  }
  const respuesta = await fetch('/api/mensajes', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!respuesta.ok) {
    $('estado').textContent = `Error ${respuesta.status}`;
    return;
  }
  const mensajes = await respuesta.json();
  $('lista').innerHTML = '';
  for (const m of mensajes) {
    const li = document.createElement('li');
    li.textContent = m.texto;
    const meta = document.createElement('div');
    meta.className = 'meta';
    meta.textContent = `${m.autor ?? 'anónimo'} · ${m.fecha ?? ''}`;
    li.appendChild(meta);
    $('lista').appendChild(li);
  }
}

// Inicio de sesión con el Hosted UI de Cognito (código de autorización con PKCE).
// El front genera un verificador aleatorio, redirige a Cognito y, al volver con ?code=..., lo cambia por tokens.
const base64url = (bytes) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

const urlCognito = () => `https://${window.COGNITO_CONFIG.domain}.auth.${window.COGNITO_CONFIG.region}.amazoncognito.com`;
const urlRetorno = () => `${location.origin}/callback`;
const urlLogout = () => `${location.origin}/logout`;

async function entrar() {
  if (!window.COGNITO_CONFIG) {
    $('estado').textContent = 'Falta config.js (lo genera cognito.sh)';
    return;
  }
  const verificador = base64url(crypto.getRandomValues(new Uint8Array(32)));
  sessionStorage.setItem('verificador', verificador);
  const desafio = base64url(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verificador)));
  const parametros = new URLSearchParams({
    response_type: 'code',
    client_id: window.COGNITO_CONFIG.clientId,
    redirect_uri: urlRetorno(),
    scope: 'openid',
    code_challenge_method: 'S256',
    code_challenge: desafio,
  });
  location.href = `${urlCognito()}/oauth2/authorize?${parametros}`;
}

// Al volver de Cognito la URL trae ?code=...: se cambia por el access token y se limpia la URL.
async function completarLogin(codigo) {
  const respuesta = await fetch(`${urlCognito()}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: window.COGNITO_CONFIG.clientId,
      code: codigo,
      redirect_uri: urlRetorno(),
      code_verifier: sessionStorage.getItem('verificador') || '',
    }),
  });
  const datos = await respuesta.json();
  history.replaceState(null, '', urlRetorno());
  if (!datos.access_token) {
    $('estado').textContent = datos.error || 'No se pudo entrar';
    return;
  }
  accessToken = datos.access_token;
  $('estado').textContent = 'Sesión iniciada';
  $('nuevo').hidden = false;
  $('salir').hidden = false;
}

// Cierra la sesión en Cognito. Cognito solo vuelve a la dirección indicada si está entre las URL de cierre
// de sesión registradas en el cliente de la aplicación.
function salir() {
  accessToken = null;
  const parametros = new URLSearchParams({
    client_id: window.COGNITO_CONFIG.clientId,
    logout_uri: urlLogout(),
  });
  location.href = `${urlCognito()}/logout?${parametros}`;
}

async function enviar() {
  const respuesta = await fetch('/api/mensajes', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({ texto: $('texto').value }),
  });
  if (respuesta.status === 201) {
    $('texto').value = '';
    await cargar();
  } else {
    $('estado').textContent = respuesta.status === 403
      ? 'Tu usuario no puede publicar (¿pertenece al grupo admin?)'
      : `Error ${respuesta.status}`;
  }
}

$('entrar').addEventListener('click', entrar);
$('salir').addEventListener('click', salir);
$('enviar').addEventListener('click', enviar);
const codigo = new URLSearchParams(location.search).get('code');
(codigo ? completarLogin(codigo) : Promise.resolve()).then(cargar);
