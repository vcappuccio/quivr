#!/bin/bash

# Function to run SQL file
run_sql_file() {
    local file="$1"
    PGPASSWORD=${DB_PASSWORD} psql -h "${DB_HOST}" -p "${DB_PORT}" -d "${DB_NAME}" -U "${DB_USER}" -f "$file"
}

# Validate if gum command is available
validate_gum() {
    if ! command -v gum &> /dev/null; then
        echo "Please install the 'gum' command or update the script to handle user input."
        exit 1
    fi
}

# Validate if psql command is available
validate_psql() {
    if ! command -v psql &> /dev/null; then
        echo "Please install 'psql' command from PostgreSQL to proceed."
        exit 1
    fi
}

# Check if .migration_info exists and source it, otherwise ask user for inputs
if [ -f .migration_info ]; then
    source .migration_info
else
    echo "Please enter the following database connection information that can be found in Supabase in Settings -> database:"
    validate_gum
    DB_HOST=$(gum input --placeholder "Host")
    DB_NAME=$(gum input --placeholder "Database name")
    DB_PORT=$(gum input --placeholder "Port")
    DB_USER=$(gum input --placeholder "User")
    DB_PASSWORD=$(gum input --placeholder "Password" --password)

    # Save the inputs in .migration_info file
    echo "DB_HOST=$DB_HOST" > .migration_info
    echo "DB_NAME=$DB_NAME" >> .migration_info
    echo "DB_PORT=$DB_PORT" >> .migration_info
    echo "DB_USER=$DB_USER" >> .migration_info
    echo "DB_PASSWORD=$DB_PASSWORD" >> .migration_info
fi

# Validate the presence of psql command
validate_psql

# Ask user whether to create tables or run migrations
CHOICE=$(gum choose --header "Choose an option" "Create all tables" "Run Migrations")

if [ "$CHOICE" == "Create all tables" ]; then
    # Running the tables.sql file to create tables
    run_sql_file "scripts/tables.sql"
else

    # Get the last migration that was executed
    LAST_MIGRATION=$(PGPASSWORD=${DB_PASSWORD} psql -h "${DB_HOST}" -p "${DB_PORT}" -d "${DB_NAME}" -U "${DB_USER}" -tAc "SELECT name FROM migrations ORDER BY executed_at DESC LIMIT 1;")

    echo "Last migration executed: $LAST_MIGRATION"
    # Iterate through the migration files
    for file in $(ls scripts | grep -E '^[0-9]+.*\.sql$' | sort); do
        MIGRATION_ID=$(basename "$file" ".sql")

        # Only run migrations that are newer than the last executed migration
        if [ -z "$LAST_MIGRATION" ] || [ "$MIGRATION_ID" \> "$LAST_MIGRATION" ]; then
            # Run the migration
            echo "Running migration $file"
            run_sql_file "scripts/$file"
            # And record it as having been run
            PGPASSWORD=${DB_PASSWORD} psql -h "${DB_HOST}" -p "${DB_PORT}" -d "${DB_NAME}" -U "${DB_USER}" -c "INSERT INTO migrations (id) VALUES ('${MIGRATION_ID}');"
        fi
    done
fi

echo "Migration script completed."
