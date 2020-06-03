#!/bin/bash

# Check if postgresql_data directory has been set up
if [ ! -d "/persistent_storage/postgresql_data" ]; then
    # Create Directory
    echo "Creating Postgres data store in persistent volume..."
    sudo mkdir /persistent_storage/postgresql_data > /dev/null 2>&1
    sudo chown postgres:postgres /persistent_storage/postgresql_data > /dev/null 2>&1
fi

# Check if odoo_data directory has been set up
if [ ! -d "/persistent_storage/odoo_data" ]; then
    # Create Directory
    echo "Creating Odoo data store in persistent volume..."
    sudo mkdir /persistent_storage/odoo_data > /dev/null 2>&1
    sudo chown odoo:odoo /persistent_storage/odoo_data > /dev/null 2>&1
fi

# Check if Postgres has been initialised
if [ -z "$(sudo ls -A /persistent_storage/postgresql_data)" ]; then
    # Initialise database
    echo "Initialising postgresql database..."
    sudo su postgres -c '/usr/lib/postgresql/10/bin/initdb -D /persistent_storage/postgresql_data' > /dev/null 2>&1

    # Create database user
    sudo service postgresql start > /dev/null 2>&1
    sudo su postgres -c 'psql -f /etc/postgresql/10/main/create_db_user.sql' > /dev/null 2>&1
fi

# Start Postgres
echo "Starting Postgres..."
sudo service postgresql start > /dev/null 2>&1

# Verify Postgres is running
if sudo lsof -Pi :5432 -sTCP:LISTEN -t >/dev/null || sudo netstat -anp | grep ':5432' | grep 'LISTEN'; then
    # Start NGINX
    echo "Starting NGINX..."
    sudo service nginx start > /dev/null 2>&1

    echo "Starting OpenSSH-Server..."
    sudo service ssh start > /dev/null 2>&1

    # Start Odoo server
    echo "Starting Odoo..."
    python3.6 /home/odoo/odoo-13/odoo/odoo-bin -c /home/odoo/odoo-server.conf
else
    echo "Failed to start Postgres, cannot start Odoo!"
fi
