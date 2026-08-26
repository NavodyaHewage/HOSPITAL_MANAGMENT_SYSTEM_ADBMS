#!/usr/bin/env bash
# Rebuilds hospital_management from the split scripts, in dependency order.
set -euo pipefail

MYSQL_USER="${1:-root}"
MYSQL_HOST="${2:-localhost}"

for file in \
    database/schema/01_schema.sql \
    database/seed/02_seed_data.sql \
    database/functions/03_functions.sql \
    database/views/04_views.sql \
    database/procedures/05_procedures.sql \
    database/triggers/06_triggers.sql
do
    echo "Loading $file ..."
    mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p --default-character-set=utf8mb4 < "$file"
done

echo "Database rebuilt."
