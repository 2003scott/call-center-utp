#!/bin/bash
# Script para crear la BD MySQL en Floci local

set -e

# Variables
DB_INSTANCE_ID="mydb"
DB_NAME="myappdb"
MASTER_USERNAME="admin"
MASTER_PASSWORD="password123"
AWS_REGION="us-east-1"
FLOCI_ENDPOINT="http://localhost:4566"

# Configurar AWS CLI para Floci
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_DEFAULT_REGION=$AWS_REGION
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

echo "Creando instancia RDS MySQL en Floci..."

# Crear la instancia RDS/MySQL
aws rds create-db-instance \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --master-username "$MASTER_USERNAME" \
  --master-user-password "$MASTER_PASSWORD" \
  --allocated-storage 20 \
  --db-name "$DB_NAME"

echo "Instancia creada. Esperando 5 segundos..."
sleep 5

# Obtener el endpoint de la BD
ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

PORT=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query 'DBInstances[0].Endpoint.Port' \
  --output text)

echo "Endpoint de la BD: $ENDPOINT"
echo "Puerto: $PORT"
echo "Usuario: $MASTER_USERNAME"
echo "Contraseña: $MASTER_PASSWORD"
echo "Base de datos: $DB_NAME"
