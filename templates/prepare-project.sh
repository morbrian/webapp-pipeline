#!/bin/bash

WORKSPACE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

NAMESPACE=$(oc project -q)

echo "Loading Templates"

oc create -f ${WORKSPACE}/minishift-volumes.yaml
oc create -f ${WORKSPACE}/postgresql-secret.yaml
oc create -f ${WORKSPACE}/crunchydata-single-master-minishift.yaml

oc create -f ${WORKSPACE}/amq-secret.yaml

#oc create -f ${WORKSPACE}/amq63-persistent.yaml

# create service account needed by amq
#oc --as system:admin create -f ${WORKSPACE}/amq-service-account.yaml
#oc policy add-role-to-user view system:serviceaccount:${NAMESPACE}:amq-service-account

oc create -f ${WORKSPACE}/maven-tomcat-pipeline.yaml

echo "Provisioning volumes"

PV_GROUP_QUALIFIER=$(oc project -q)
USER_HOME=$( echo ${HOME} | sed 's/\/c//')
BACKUP_PV_PATH="${HOME}/minidata/backup"
PGCONF_PV_PATH="${HOME}/minidata/app-pgconf"

oc process \
    -p PG_BACKUP_PV_PATH=${BACKUP_PV_PATH} \
    -p PG_PGCONF_PV_PATH=${PGCONF_PV_PATH} \
    -p PG_PV_GROUP_QUALIFIER=${PV_GROUP_QUALIFIER} \
    minishift-volumes | oc --as system:admin create -f -

echo "Creating Instances"

export APP_NAME=jdbcquery
export APP_NAME_UPPER=$(echo ${APP_NAME} | awk '{print toupper($0)}')
export BACKEND_DB_SECRET=${APP_NAME}-${APP_NAME}-secret
export BACKEND_DB_SERVICE=${APP_NAME}-data
export BACKEND_DB_NAME=${APP_NAME}
export BACKEND_RESTORE_PATH=skip-restore

# create database secret from template
oc process \
    -p SECRET_NAME=${BACKEND_DB_SECRET} \
    -n ${NAMESPACE} \
    postgresql-secret | oc replace --force -n ${NAMESPACE} -f -

# create amq secret from template
oc process \
    -p APP_NAME=${APP_NAME} \
    -n ${NAMESPACE} \
    amq-secret | oc replace --force -n ${NAMESPACE} -f -

# create database instance from template
oc process \
    -p PG_RESTORE_PATH=${BACKEND_RESTORE_PATH} \
    -p PG_SERVICE_NAME=${BACKEND_DB_SERVICE} \
    -p SECRET_NAME=${BACKEND_DB_SECRET} \
    -p PG_DATABASE=${BACKEND_DB_NAME} \
    -n ${NAMESPACE} \
    crunchydata-single-master-minishift | oc replace --force -n ${NAMESPACE} -f -

# create pipeline from template
oc process \
    -p APP_NAME=${APP_NAME} \
    -p APP_NAME_UPPER=${APP_NAME_UPPER} \
    -p ARTIFACT_NAME=jdbc-query \
    -p BACKEND_DB_SERVICE=${BACKEND_DB_SERVICE} \
    -p BACKEND_DB_NAME=${BACKEND_DB_NAME} \
    -p BACKEND_DB_SECRET=${BACKEND_DB_SECRET} \
    -p BACKEND_RESTORE_PATH=${BACKEND_RESTORE_PATH} \
    maven-tomcat-pipeline | oc create -f -
