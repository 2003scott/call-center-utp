# Desarrollo Local con Floci + MySQL

## Instalación y Uso

Solo ejecuta:
```bash
docker compose up -d
```

**Eso es todo.** El compose automáticamente:
1. Levanta Floci
2. Espera a que esté listo
3. Crea la BD MySQL
4. Inicializa las tablas

En ~10-15 segundos, tu BD quedará lista en el puerto que te devuelva Floci y el script generará `.env.local` con los datos correctos.

## Conexión desde tu App

Tu app lee las variables de `.env.local`:
```
DB_HOST=localhost
DB_PORT=7001
DB_USER=admin
DB_PASSWORD=password123
DB_NAME=myappdb
```

Usa estas credenciales para conectarte a `localhost:3306`.

## Estructura de archivos

```
docker-compose.yml   ← Floci + inicialización automática
init-db.sql          ← Esquema de call center y datos semilla
init-all.sh          ← Script de inicialización (automático)
.env.local           ← Variables reales generadas por el script
.gitignore           ← Excluye archivos sensibles
```

## Después de clonar el repo

Tu amigo clona el proyecto y ejecuta:
```bash
docker compose up -d
```

En menos de 15 segundos, todo está listo para trabajar.

