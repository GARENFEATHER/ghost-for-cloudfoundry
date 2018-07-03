#!/bin/bash

set -e -u

# App URL
app_uri="$(echo "${VCAP_APPLICATION}" | jq -r '.application_uris[0] // ""')"
app_url="https://${app_uri}"
app_eternal_url="https://ghost.garenfeather.cn"

# Database
db_credentials="$(echo "${VCAP_SERVICES}" | jq -r '.["cleardb"][0].credentials // ""')"
if [ -z "${db_credentials}" ]; then
  echo "Error: Please bind a MariaDB service" >&2
  exit 1
fi
db_host="$(echo "${db_credentials}" | jq -r '.hostname // ""')"
db_username="$(echo "${db_credentials}" | jq -r '.username // ""')"
db_password="$(echo "${db_credentials}" | jq -r '.password // ""')"
db_database="$(echo "${db_credentials}" | jq -r '.name // ""')"

echo "credentials: ${db_credentials}"

# Email service
email_credentials="$(echo "${VCAP_SERVICES}" | jq -r '.["user-provided"][0].credentials // ""')"
if [ -z "${email_credentials}" ]; then
  echo "Error: Please bind an Email service" >&2
  exit 1
fi
email_username="$(echo "${email_credentials}" | jq -r '.username // ""')"
email_password="$(echo "${email_credentials}" | jq -r '.password // ""')"

# Create config file
jq -n "{
    url: \"${app_eternal_url}\",
    mail: {
        transport: \"SMTP\",
        options: {
            service: \"Mailgun\",
            auth: {
                user: \"${email_username}\",
                pass: \"${email_password}\"
            }
        }
    },
    database: {
        client: \"mysql\",
        connection: {
            host: \"${db_host}\",
            user: \"${db_username}\",
            password: \"${db_password}\",
            database: \"${db_database}\",
            connectionLimit: 2
        },
        pool: {
            min: 1,
            max: 3
        }
    },
    server: {
        host: \"0.0.0.0\",
        port: ${PORT}
    }
}" > config.production.json

# Initialize and Migrate DB
./node_modules/.bin/knex-migrator init
./node_modules/.bin/knex-migrator migrate

# Start the app
npm start
