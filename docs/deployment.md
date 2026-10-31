# Deployment

## Flujo previsto

1. Desarrollo local con Flutter.
2. Repositorio remoto en GitHub.
3. Backend en Supabase.
4. Deploy web automatico en Vercel conectado al repo.

## Local

Los servidores públicos de OSRM y Nominatim son solo para pruebas; para uso real conviene configurar servicios propios o proveedores adecuados. OSRM calcula rutas con el perfil `driving` (autos).

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY \
  --dart-define=OSRM_BASE_URL=${OSRM_BASE_URL:-https://router.project-osrm.org}
```

Sin configuración de Supabase, la calculadora sigue abriendo, pero guardar perfil, vehículo o viaje informa que no hay persistencia. No se presenta el fallback en memoria como un guardado permanente.

## Supabase

1. Crear el proyecto en Supabase.
2. Habilitar el proveedor **Anonymous Sign-Ins** y **Email** en Auth. Mantener activada la confirmación de correo.
3. Configurar `Site URL` y las URL permitidas para el dominio web de Netokm y `http://localhost:PORT` en pruebas locales; los enlaces de verificación y recuperación deben volver a una URL permitida.
4. Enlazar el proyecto local y aplicar las migraciones versionadas:

   ```bash
   supabase link --project-ref <project-ref>
   supabase db push
   ```

   Las migraciones crean `profiles`, amplían `vehicle_profiles` sin borrar sus filas y agregan fotografías del vehículo a los viajes. No aplicar `schema.sql` sobre una base existente; ese archivo es la definición para un proyecto nuevo.

5. Configurar las variables públicas:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`

No usar service role keys en Flutter ni en Vercel para esta app cliente.

La app crea o restaura una sesión anónima al iniciar. **Proteger mis viajes** actualiza el correo y la contraseña de esa misma sesión; Supabase envía la verificación y el UUID no cambia. Si el correo ya existe, la app ofrece iniciar sesión en esa cuenta y avisa que no fusiona ni transfiere los datos anónimos. La recuperación se envía desde la pantalla Cuenta. Configurar los proveedores y enlaces en Supabase es necesario para que esos correos lleguen.

El perfil personal y el vehículo principal se guardan en tablas con RLS. Los viajes guardan ruta, costos, resultado y una fotografía del vehículo. El comparador elige de ese historial y calcula sus indicadores desde esos valores guardados.

Las políticas RLS se pueden validar en un proyecto local con `supabase test db`. La aplicación requiere solo la URL y la publishable key; nunca incluir la service-role key.

## Vercel

Conectar el repo de GitHub desde Vercel y configurar:

- Framework Preset: Other
- Build Command: `bash scripts/build_web.sh`
- Output Directory: `build/web`

Variables requeridas:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `OSRM_BASE_URL` opcional, por defecto `https://router.project-osrm.org`

Variable opcional para habilitar el modo **Viaje personal** (se muestra como Beta). Por defecto es `false`, por lo que la aplicación ofrece únicamente **Flete**:

- `ENABLE_PERSONAL_MODE`: `true` para mostrar y habilitar Viaje personal; `false` para mantenerlo oculto.
- `NOMINATIM_CONTACT_EMAIL`: correo genérico de contacto de Netokm para identificar la app ante Nominatim. No configures un correo personal. Si queda vacío, no se envía el parámetro `email` y se muestra una advertencia de depuración.
- `FEEDBACK_WHATSAPP`: opcional, teléfono de WhatsApp con código de país y solo dígitos. Si queda vacío o tiene caracteres inválidos, el enlace de feedback se oculta.

El script `scripts/build_web.sh` instala Flutter en el entorno de build si no esta disponible y compila Flutter Web.

Variable opcional para fijar la version de Flutter usada en Vercel:

- `FLUTTER_VERSION`, por defecto `3.27.4`

## GitHub CI

`.github/workflows/flutter-ci.yml` ejecuta:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `bash scripts/build_web.sh`
