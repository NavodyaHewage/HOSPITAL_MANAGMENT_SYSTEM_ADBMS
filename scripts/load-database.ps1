# Rebuilds hospital_management from the split scripts, in dependency order.
param(
    [string]$MysqlUser = "root",
    [string]$MysqlHost = "localhost"
)

$files = @(
    "database/schema/01_schema.sql",
    "database/seed/02_seed_data.sql",
    "database/functions/03_functions.sql",
    "database/views/04_views.sql",
    "database/procedures/05_procedures.sql",
    "database/triggers/06_triggers.sql"
)

foreach ($file in $files) {
    Write-Host "Loading $file ..."
    mysql -h $MysqlHost -u $MysqlUser -p --default-character-set=utf8mb4 < $file
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed on $file"
        exit 1
    }
}

Write-Host "Database rebuilt."
