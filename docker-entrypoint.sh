#!/bin/bash
set -e

# Default port for Render
export PORT="${PORT:-10000}"

# Generate config.php from environment variables
if [ -n "$DATABASE_URL" ]; then
    # Parse DATABASE_URL (format: postgres://user:password@host:port/dbname)
    proto="$(echo $DATABASE_URL | grep :// | sed -e 's,^\(.*://\).*,\1,g')"
    url="$(echo ${DATABASE_URL/$proto/})"
    userpass="$(echo $url | grep @ | cut -d@ -f1)"
    DB_USER="$(echo $userpass | cut -d: -f1)"
    DB_PASS="$(echo $userpass | cut -d: -f2)"
    hostport="$(echo ${url/$userpass@/} | cut -d/ -f1)"
    DB_HOST="$(echo $hostport | cut -d: -f1)"
    DB_PORT="$(echo $hostport | cut -d: -f2)"
    DB_NAME="$(echo $url | grep / | cut -d/ -f2 | cut -d? -f1)"

    cat > /var/www/html/config.php <<CFGEOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'pgsql';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '${DB_HOST}';
\$CFG->dbname    = '${DB_NAME}';
\$CFG->dbuser    = '${DB_USER}';
\$CFG->dbpass    = '${DB_PASS}';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
    'dbport' => '${DB_PORT}',
    'dbsocket' => '',
);

\$CFG->wwwroot   = '${MOODLE_URL:-http://localhost}';
\$CFG->dataroot  = '/var/www/moodledata';
\$CFG->admin     = 'admin';
\$CFG->directorypermissions = 0775;

// Performance settings
\$CFG->cachedir = '/var/www/moodledata/cache';
\$CFG->localcachedir = '/tmp/moodlelocalcache';
@mkdir(\$CFG->localcachedir, 0775, true);

require_once(__DIR__ . '/lib/setup.php');
CFGEOF

    chown www-data:www-data /var/www/html/config.php
fi

# Ensure moodledata permissions
chown -R www-data:www-data /var/www/moodledata

# Run Moodle install/upgrade if needed
if [ -n "$DATABASE_URL" ] && [ -n "$MOODLE_INSTALL" ]; then
    php /var/www/html/admin/cli/install_database.php \
        --agree-license \
        --fullname="Sistemas de Gestión de la Calidad en Salud" \
        --shortname="SGC" \
        --adminuser="${MOODLE_ADMIN_USER:-admin}" \
        --adminpass="${MOODLE_ADMIN_PASS:-Admin1234!}" \
        --adminemail="${MOODLE_ADMIN_EMAIL:-admin@example.com}" \
        || true
fi

# Run upgrade if needed
if [ -f /var/www/html/config.php ]; then
    php /var/www/html/admin/cli/upgrade.php --non-interactive || true
fi

# Setup cron
echo "*/1 * * * * www-data /usr/local/bin/php /var/www/html/admin/cli/cron.php > /dev/null 2>&1" > /etc/cron.d/moodle-cron
chmod 0644 /etc/cron.d/moodle-cron
service cron start || true

exec "$@"
