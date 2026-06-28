#!/bin/bash
# Script para conectarse a la BD y ejecutar el init-db.sql

set -e

if [ -f .env.local ]; then
  set -a
  . ./.env.local
  set +a
fi

MASTER_USERNAME="${DB_USER:-admin}"
MASTER_PASSWORD="${DB_PASSWORD:-password123}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-7001}"
DB_NAME="${DB_NAME:-myappdb}"

echo "Conectando a MySQL en Floci y ejecutando init-db.sql..."

# Ejecutar el archivo SQL
MYSQL_PWD="$MASTER_PASSWORD" mysql -h "$DB_HOST" \
  -P "$DB_PORT" \
  -u "$MASTER_USERNAME" \
  --ssl-mode=DISABLED \
  "$DB_NAME" < init-db.sql

echo "Base de datos inicializada."
