#!/bin/bash
set -Eeuo pipefail

required_variables=(
  MYSQL_ROOT_PASSWORD
  SPRING_DB_NAME
  SPRING_DB_USER
  SPRING_DB_PASSWORD
  FASTAPI_DB_NAME
  FASTAPI_DB_USER
  FASTAPI_DB_PASSWORD
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "Missing required environment variable: ${variable_name}" >&2
    exit 1
  fi
done

for identifier in "$SPRING_DB_NAME" "$SPRING_DB_USER" "$FASTAPI_DB_NAME" "$FASTAPI_DB_USER"; do
  if [[ ! "$identifier" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Database and user names may contain only letters, numbers, and underscores: ${identifier}" >&2
    exit 1
  fi
done

spring_password=${SPRING_DB_PASSWORD//\\/\\\\}
spring_password=${spring_password//\'/\'\'}
fastapi_password=${FASTAPI_DB_PASSWORD//\\/\\\\}
fastapi_password=${fastapi_password//\'/\'\'}

export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
mysql --protocol=socket -uroot <<EOSQL
CREATE DATABASE IF NOT EXISTS \`${SPRING_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${SPRING_DB_USER}'@'%' IDENTIFIED BY '${spring_password}';
ALTER USER '${SPRING_DB_USER}'@'%' IDENTIFIED BY '${spring_password}';
GRANT ALL PRIVILEGES ON \`${SPRING_DB_NAME}\`.* TO '${SPRING_DB_USER}'@'%';

CREATE DATABASE IF NOT EXISTS \`${FASTAPI_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${FASTAPI_DB_USER}'@'%' IDENTIFIED BY '${fastapi_password}';
ALTER USER '${FASTAPI_DB_USER}'@'%' IDENTIFIED BY '${fastapi_password}';
GRANT ALL PRIVILEGES ON \`${FASTAPI_DB_NAME}\`.* TO '${FASTAPI_DB_USER}'@'%';
EOSQL

unset MYSQL_PWD

# Deploy는 DB와 계정만 준비한다. 서비스별 테이블은 각 애플리케이션 migration이 관리한다.
