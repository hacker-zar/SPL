# Deployment

## Flujo previsto

1. Desarrollo local con Flutter.
2. Repositorio remoto en GitHub.
3. Backend en Supabase.
4. Deploy web automatico en Vercel conectado al repo.

## Local

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY \
  --dart-define=OSRM_BASE_URL=${OSRM_BASE_URL:-https://router.project-osrm.org}
```

Si faltan variables, la app cae a repositorios en memoria para desarrollo de UI.

## Supabase

1. Crear el proyecto en Supabase.
2. Habilitar Auth anonimo si se quiere mantener el flujo sin registro en el MVP.
3. Ejecutar `supabase/schema.sql` desde SQL Editor o convertirlo a una migracion con Supabase CLI.
4. Configurar las variables publicas:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`

No usar service role keys en Flutter ni en Vercel para esta app cliente.

## Vercel

Conectar el repo de GitHub desde Vercel y configurar:

- Framework Preset: Other
- Build Command: `bash scripts/build_web.sh`
- Output Directory: `build/web`

Variables requeridas:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `OSRM_BASE_URL` opcional, por defecto `https://router.project-osrm.org`

El script `scripts/build_web.sh` instala Flutter en el entorno de build si no esta disponible y compila Flutter Web.

Variable opcional para fijar la version de Flutter usada en Vercel:

- `FLUTTER_VERSION`, por defecto `3.27.4`

## GitHub CI

`.github/workflows/flutter-ci.yml` ejecuta:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `bash scripts/build_web.sh`
