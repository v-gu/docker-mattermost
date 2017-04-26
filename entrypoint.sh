#!/bin/bash
set -e

if [[ $DEBUG == true ]]; then
  set -x
  export MM_LOGSETTINGS_CONSOLE_LEVEL=DEBUG
  echo "======================"
  echo "Environment variables:"
  env
  echo "======================"
fi

#### Helper functions

vercmp() {
  # Compares two version strings `a` and `b`
  # Returns
  #   - negative integer, if `a` is less than `b`
  #   - 0, if `a` and `b` are equal
  #   - non-negative integer, if `a` is greater than `b`
  expr '(' "$1" : '\([^.]*\)' ')' '-' '(' "$2" : '\([^.]*\)' ')' '|' \
       '(' "$1.0" : '[^.]*[.]\([^.]*\)' ')' '-' '(' "$2.0" : '[^.]*[.]\([^.]*\)' ')' '|' \
       '(' "$1.0.0" : '[^.]*[.][^.]*[.]\([^.]*\)' ')' '-' '(' "$2.0.0" : '[^.]*[.][^.]*[.]\([^.]*\)' ')' '|' \
       '(' "$1.0.0.0" : '[^.]*[.][^.]*[.][^.]*[.]\([^.]*\)' ')' '-' '(' "$2.0.0.0" : '[^.]*[.][^.]*[.][^.]*[.]\([^.]*\)' ')'
}

configure_database() {
  echo "Configuring database..."
  finalize_database_parameters
  check_database_connection
  create_missing_database
}

finalize_database_parameters() {
  # is a mysql or postgresql named host available?
  echo -n "Trying to locate a database container."
  for ((i=0;i<10;i++)); do
    if ping -c1 -W1 mysql &> /dev/null; then
      MM_SQLSETTINGS_DRIVERNAME=${MM_SQLSETTINGS_DRIVERNAME:-mysql}
      DB_HOST=${DB_HOST:-mysql}
      echo -e "\u2714"
      break
    elif ping -c1 -W1 postgres &> /dev/null; then
      MM_SQLSETTINGS_DRIVERNAME=${MM_SQLSETTINGS_DRIVERNAME:-postgres}
      DB_HOST=${DB_HOST:-postgres}
      echo -e "\u2714"
      break
    fi
    echo -n "."
    sleep 1
  done

  # db agnostic defaults
  DB_NAME=${DB_NAME:-mattermost}

  # assemble datasource url
  case ${MM_SQLSETTINGS_DRIVERNAME} in
    mysql)
      DB_PORT=${DB_PORT:-3306}
      DB_USER=${DB_USER:-root}
      DB_ENCODING=${DB_ENCODING:-utf8mb4,utf8}
      DB_PARAMS="charset=${DB_ENCODING}"
      export MM_SQLSETTINGS_DATASOURCE="${DB_USER}:${DB_PASS}@tcp(${DB_HOST}:${DB_PORT})/${DB_NAME}?${DB_PARAMS}"
      ;;
    postgres)
      DB_PORT=${DB_PORT:-5432}
      DB_USER=${DB_USER:-postgres}
      DB_PARAMS="sslmode=disable&connect_timeout=10"
      export MM_SQLSETTINGS_DATASOURCE="postgres://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}?${DB_PARAMS}"
      ;;
    *)
      echo
      echo "ERROR: Supported values for MM_SQLSETTINGS_DRIVERNAME are 'postgres' and 'mysql'."
      echo
      exit 1
      ;;
  esac

}

check_database_connection() {
  local check

  echo -n "Checking database connection"
  case ${MM_SQLSETTINGS_DRIVERNAME} in
    mysql)
      check=(mysqladmin -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} -p${DB_PASS} status)
      ;;
    postgres)
      export PGPASSWORD=${DB_PASS}
      check=(psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER})
      ;;
  esac

  connectable=1
  for ((i=0;i<60;i++)); do
    if "${check[@]}" &> /dev/null; then
      connectable=0
      break
    fi
    echo -n "."
    sleep 1
  done

  if [[ $connectable -eq 1 ]]; then
    echo
    echo "Could not connect to database server. Aborting..."
    exit 1
  else
    echo -e "\u2714"
  fi

}

create_missing_database() {
  echo -n "Testing whether database ${DB_NAME} exists. "

  case ${MM_SQLSETTINGS_DRIVERNAME} in
    mysql)
      echo -n "Creating database ${DB_NAME} if necessary. "
      mysql -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} -p${DB_PASS} mysql << EOF
        CREATE DATABASE IF NOT EXISTS ${DB_NAME};
        GRANT ALL PRIVILEGES ON ${DB_NAME} TO ${DB_USER};
EOF
      echo -e "\u2714"
      ;;
    postgres)
      if psql ${MM_SQLSETTINGS_DATASOURCE}; then
        echo -e "\u2714"
      else
        echo -e "\u2718"
        echo -n "Creating database ${DB_NAME}. "
        psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} << EOF
          CREATE DATABASE ${DB_NAME} WITH OWNER ${DB_USER};
          GRANT ALL PRIVILEGES ON ${DB_NAME} TO ${DB_USER};
EOF
        echo -e "\u2714"
      fi
      ;;

  esac
}

check_version() {
  if [ -f ${MATTERMOST_DATA_DIR}/VERSION ]; then
    CACHE_VERSION=$(cat ${MATTERMOST_DATA_DIR}/VERSION)
  else
    CACHE_VERSION=${MATTERMOST_VERSION}
  fi

  if [[ $(vercmp ${MATTERMOST_VERSION} ${CACHE_VERSION}) -lt 0 ]]; then
    echo
    echo "ERROR: "
    echo "  Cannot downgrade from Mattermost version ${CACHE_VERSION} to ${MATTERMOST_VERSION}."
    echo "  Only upgrades are allowed. Please use jasl8r/mattermost:${CACHE_VERSION} or higher."
    echo "  Cannot continue. Aborting!"
    echo
    exit 1
  fi

  if [[ $(vercmp ${CACHE_VERSION} 3.5.1) -lt 0 ]]; then
    echo
    echo "ERROR: "
    echo "  Cannot upgrade from Mattermost version ${CACHE_VERSION} to ${MATTERMOST_VERSION}."
    echo "  Mattermost version ${CACHE_VERSION} must be upgraded to version 3.5.1 first."
    echo "  Please run jasl8r/mattermost:3.5.1 followed by funkyfuture/mattermost:${MATTERMOST_VERSION}"
    echo "  Cannot continue. Aborting!"
    echo
    exit 1
  fi

  echo "${MATTERMOST_VERSION}" > ${MATTERMOST_DATA_DIR}/VERSION
}

#### Main procedure

# ensure file access
chmod 750 ${MATTERMOST_DATA_DIR}
chown -R "$(id -u):$(id -g)" ${MATTERMOST_DATA_DIR}

# database configuration
check_version
configure_database

for setting_variable in ${!MM_*}; do
  eval "export ${setting_variable}"
done

exec ./bin/platform --config ${MATTERMOST_CONF_DIR}/config.json "$@"

exit 1
