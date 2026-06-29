# Call Center UTP

## Levantar todo con Docker Compose

1. Copia `.env.example` a `.env` y ajusta los valores si lo necesitas.
2. Desde la raíz del proyecto ejecuta:

```bash
docker compose up --build
```

## Servicios expuestos

- Orquestador: `http://localhost:3001`
- FreePBX / Asterisk: `http://localhost:8080`
- Floci: `http://localhost:4566`

## Notas

- El orquestador apunta a `asterisk_pbx` dentro de la red de Compose.
- Floci usa la red fija `callcenter_net` para poder crear sus servicios RDS en el mismo entorno.
- La inicialización de base de datos vive en `db-floci/init-all.sh` y `db-floci/init-db.sql`.
