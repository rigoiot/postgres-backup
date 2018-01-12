#!/bin/bash
[ -z "${POSTGRES_HOST}" ] && { echo "=> POSTGRES_HOST cannot be empty" && exit 1; }
[ -z "${POSTGRES_PORT}" ] && { echo "=> POSTGRES_PORT cannot be empty" && exit 1; }
[ -z "${POSTGRES_USER}" ] && { echo "=> POSTGRES_USER cannot be empty" && exit 1; }
[ -z "${POSTGRES_PASSWORD}" ] && { echo "=> POSTGRES_PASSWORD cannot be empty" && exit 1; }
[ -z "${POSTGRES_DB}" ] && { echo "=> POSTGRES_DB cannot be empty" && exit 1; }

export PGPASSWORD="${POSTGRES_PASSWORD}"

while getopts ":d:c" opt; do
  case $opt in
    d)
      echo "Restoring file '$OPTARG'..." >&2
      DUMP_FILE_PATH=$OPTARG
      ;;
    c)
      echo "Will create fresh database..."
      FRESH_DB=true
    ;;
  esac
done

if [[ -n ${FRESH_DB} ]]; then
  createdb -h ${POSTGRES_HOST} -U ${POSTGRES_USER} ${POSTGRES_DB}
fi

pg_restore -c /backup/${DUMP_FILE_PATH} -h ${POSTGRES_HOST} -U ${POSTGRES_USER} -d ${POSTGRES_DB}