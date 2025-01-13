#!/bin/bash
set -e

echo "Creating databases..."

psql -a  -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE DATABASE baw_development_sftpgo;
    CREATE DATABASE baw_test_sftpgo;

    GRANT ALL PRIVILEGES ON DATABASE baw_development_sftpgo TO postgres;
    GRANT ALL PRIVILEGES ON DATABASE baw_test_sftpgo TO postgres;
EOSQL