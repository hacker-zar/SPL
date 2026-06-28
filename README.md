# Conviene este viaje?

MVP Flutter para un chofer o transportista independiente.

La app responde una sola pregunta: **me conviene aceptar este viaje?**

## Alcance implementado

- Arquitectura por funcionalidades en `lib/features`.
- Calculadora de rentabilidad desacoplada de la UI.
- Flujo corto: ruta, oferta/costos minimos y resultado.
- Respuesta principal como primer elemento: si conviene, margen bajo o no aceptar.
- Opcion de regreso vacio que duplica kilometros, tiempo, combustible y mantenimiento.
- Perfil unico del vehiculo: consumo, mantenimiento por km, capacidad y patente opcional.
- Historial de simulaciones.
- Supabase como backend principal: Auth, PostgreSQL y Storage preparado.
- Repositorios en memoria solo como fallback local si no hay variables de Supabase.

## Configuracion local

Este workspace no tiene Flutter/Dart instalados, por eso no se pudo ejecutar ni compilar aca.

En una maquina con Flutter:

```bash
flutter pub get
flutter create .
flutter run \
  --dart-define=SUPABASE_URL=TU_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_PUBLISHABLE_KEY \
  --dart-define=OSRM_BASE_URL=https://router.project-osrm.org
```

## Supabase

El esquema inicial esta en `supabase/schema.sql`.

Datos:

- `auth.users`, administrada por Supabase Auth
- `vehicle_profiles`
- `trips`

La app usa Supabase Auth. En el MVP intenta crear una sesion anonima para que el chofer pueda simular sin friccion. Las tablas usan `user_id`, RLS y politicas por propietario.

Storage queda preparado con el bucket privado `trip_attachments` para futuros comprobantes, cartas de porte o reportes.

## Mapas y rutas

La app usa OpenStreetMap para visualizar mapas con `flutter_map` y OSRM para calcular ruta, distancia, duracion y geometria. No requiere cuenta de facturacion ni tarjeta bancaria para mapas.

`OSRM_BASE_URL` permite cambiar el proveedor/servidor de rutas sin tocar la UI ni la logica financiera.

## Vercel

`vercel.json` usa `scripts/build_web.sh` para construir la version web con Flutter y pasar `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` como `dart-define`.

Ver el flujo completo en `docs/deployment.md`.
