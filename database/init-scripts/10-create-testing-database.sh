#!/usr/bin/env bash

if [ ! -z "$MYSQL_DATABASE" ]; then
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE}_test;"
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}_test.* TO '$MYSQL_USER'@'%';"
    echo "Created test database ${MYSQL_DATABASE}_test"
fi
