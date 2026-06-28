#!/bin/bash
# Script que automatiza TODO: crea BD y tablas en Floci

set -e

# Variables
DB_INSTANCE_ID="mydb"
DB_NAME="myappdb"
MASTER_USERNAME="admin"
MASTER_PASSWORD="password123"
AWS_REGION="us-east-1"
FLOCI_ENDPOINT="http://floci:4566"
MAX_RETRIES=30
RETRY_DELAY=2
DB_HOST=""
DB_PORT=""

# Configurar AWS CLI para Floci
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_DEFAULT_REGION=$AWS_REGION
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

echo "============================================"
echo "Inicializando Floci + MySQL..."
echo "============================================"

# 1. ESPERAR A QUE FLOCI ESTÉ LISTO
echo ""
echo "[1/3] Esperando a que Floci esté disponible..."
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s $FLOCI_ENDPOINT/health >/dev/null 2>&1 || \
     aws sts get-caller-identity >/dev/null 2>&1; then
    echo "✓ Floci está listo"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "  Intento $RETRY_COUNT/$MAX_RETRIES... esperando $RETRY_DELAY segundos"
  sleep $RETRY_DELAY
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "✗ Floci no respondió después de $(($MAX_RETRIES * $RETRY_DELAY)) segundos"
  exit 1
fi

# 2. CREAR LA BD
echo ""
echo "[2/3] Creando instancia RDS MySQL..."

# Verificar si ya existe
if aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID >/dev/null 2>&1; then
  echo "✓ Instancia $DB_INSTANCE_ID ya existe"
else
  aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_ID \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username $MASTER_USERNAME \
    --master-user-password $MASTER_PASSWORD \
    --allocated-storage 20 \
    --db-name $DB_NAME \
    >/dev/null 2>&1
  echo "✓ Instancia creada"
fi

# Esperar a que Floci registre el endpoint y obtener host/puerto reales
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  DB_HOST=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text 2>/dev/null || true)
  DB_PORT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_ID \
    --query 'DBInstances[0].Endpoint.Port' \
    --output text 2>/dev/null || true)

  if [ -n "$DB_HOST" ] && [ "$DB_HOST" != "None" ] && [ -n "$DB_PORT" ] && [ "$DB_PORT" != "None" ]; then
    echo "✓ Endpoint listo: $DB_HOST:$DB_PORT"
    break
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "  Esperando endpoint de la BD... intento $RETRY_COUNT/$MAX_RETRIES"
  sleep $RETRY_DELAY
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "⚠ Instancia existente sin endpoint; recreando $DB_INSTANCE_ID"
  aws rds delete-db-instance --db-instance-identifier $DB_INSTANCE_ID >/dev/null 2>&1 || true

  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID >/dev/null 2>&1; then
      break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep $RETRY_DELAY
  done

  aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_ID \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username $MASTER_USERNAME \
    --master-user-password $MASTER_PASSWORD \
    --allocated-storage 20 \
    --db-name $DB_NAME \
    >/dev/null 2>&1

  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    DB_HOST=$(aws rds describe-db-instances \
      --db-instance-identifier $DB_INSTANCE_ID \
      --query 'DBInstances[0].Endpoint.Address' \
      --output text 2>/dev/null || true)
    DB_PORT=$(aws rds describe-db-instances \
      --db-instance-identifier $DB_INSTANCE_ID \
      --query 'DBInstances[0].Endpoint.Port' \
      --output text 2>/dev/null || true)

    if [ -n "$DB_HOST" ] && [ "$DB_HOST" != "None" ] && [ -n "$DB_PORT" ] && [ "$DB_PORT" != "None" ]; then
      echo "✓ Endpoint listo: $DB_HOST:$DB_PORT"
      break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "  Esperando endpoint de la BD recreada... intento $RETRY_COUNT/$MAX_RETRIES"
    sleep $RETRY_DELAY
  done

  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "✗ No se pudo obtener el endpoint de la BD"
    exit 1
  fi
fi

# 3. CONECTAR E INICIALIZAR TABLAS
echo ""
echo "[3/3] Inicializando tablas..."

# Esperar a que MySQL esté listo
RETRY_COUNT=0
LAST_MYSQL_ERROR=""
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if MYSQL_PWD="$MASTER_PASSWORD" mysql -h "$DB_HOST" \
    -P "$DB_PORT" \
    -u $MASTER_USERNAME \
    --ssl-mode=DISABLED \
    "$DB_NAME" -e "SELECT 1" >/dev/null 2>&1; then
    echo "✓ MySQL está listo"
    break
  fi
  LAST_MYSQL_ERROR=$(MYSQL_PWD="$MASTER_PASSWORD" mysql -h "$DB_HOST" \
    -P "$DB_PORT" \
    -u $MASTER_USERNAME \
    --ssl-mode=DISABLED \
    "$DB_NAME" -e "SELECT 1" 2>&1 || true)
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "  Intento $RETRY_COUNT/$MAX_RETRIES... esperando $RETRY_DELAY segundos"
  echo "  mysql: $LAST_MYSQL_ERROR"
  sleep $RETRY_DELAY
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "✗ MySQL no respondió"
  echo "Último error de mysql: $LAST_MYSQL_ERROR"
  exit 1
fi

# Ejecutar el SQL
MYSQL_PWD="$MASTER_PASSWORD" mysql -h "$DB_HOST" \
  -P "$DB_PORT" \
  -u $MASTER_USERNAME \
  --ssl-mode=DISABLED \
  "$DB_NAME" < init-db.sql

echo "✓ Tablas creadas"

cat > .env.local <<EOF
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_USER=$MASTER_USERNAME
DB_PASSWORD=$MASTER_PASSWORD
DB_NAME=$DB_NAME
DB_ENGINE=mysql
EOF

echo "✓ Archivo .env.local generado"

echo ""
echo "============================================"
echo "✓ LISTO! Base de datos inicializada"
echo "============================================"
echo ""
echo "Detalles de conexión:"
echo "  Host: $DB_HOST"
echo "  Puerto: $DB_PORT"
echo "  Usuario: $MASTER_USERNAME"
echo "  Contraseña: $MASTER_PASSWORD"
echo "  Base de datos: $DB_NAME"
echo ""
echo "Tu app puede conectarse ahora mismo."
