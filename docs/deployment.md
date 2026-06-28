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
  --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
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
- `GOOGLE_MAPS_API_KEY`

El script `scripts/build_web.sh` instala Flutter en el entorno de build si no esta disponible y compila Flutter Web.

## GitHub CI

`.github/workflows/flutter-ci.yml` ejecuta:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `bash scripts/build_web.sh`
