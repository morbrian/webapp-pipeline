#!/bin/bash

WORKSPACE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

NAMESPACE=$(oc project -q)

export APP_ID=jdbcquery

echo "Loading Templates"

oc create -f ${WORKSPACE}/minishift-volumes.yaml
oc create -f ${WORKSPACE}/crunchydata-single-master-minishift.yaml
oc create -f ${WORKSPACE}/jdbcquery-backend-pipeline.yaml

#oc create -f ${WORKSPACE}/amq-secret.yaml
#oc create -f ${WORKSPACE}/amq63-persistent.yaml

# create service account needed by amq
#oc --as system:admin create -f ${WORKSPACE}/amq-service-account.yaml
#oc policy add-role-to-user view system:serviceaccount:${NAMESPACE}:amq-service-account

echo "Provisioning volumes"

PV_GROUP_QUALIFIER=$(oc project -q)
BACKUP_PV_PATH="/Users/bmoriarty/minidata/backup"
PGCONF_PV_PATH="/Users/bmoriarty/minidata/app-pgconf"
#BACKUP_PV_PATH="${HOME}/minidata/backup"
#PGCONF_PV_PATH="${HOME}/minidata/app-pgconf"

oc process \
    -p APP_ID=${APP_ID} \
    -p PG_PV_DB_LABEL=data \
    -p PG_BACKUP_PV_PATH=${BACKUP_PV_PATH} \
    -p PG_PGCONF_PV_PATH=${PGCONF_PV_PATH} \
    -p PG_PV_GROUP_QUALIFIER=${PV_GROUP_QUALIFIER} \
    minishift-volumes | oc --as system:admin create -f -

oc process \
    -p APP_ID=${APP_ID} \
    -p PG_PV_DB_LABEL=lob \
    -p PG_BACKUP_PV_PATH=${BACKUP_PV_PATH} \
    -p PG_PGCONF_PV_PATH=${PGCONF_PV_PATH} \
    -p PG_PV_GROUP_QUALIFIER=${PV_GROUP_QUALIFIER} \
    minishift-volumes | oc --as system:admin create -f -

echo "Creating Instances"


export DATA_RESTORE_PATH=skip-restore
export LOB_RESTORE_PATH=skip-restore

# create amq secret from template
#oc process \
#    -p APP_NAME=${APP_NAME} \
#    -n ${NAMESPACE} \
#    amq-secret | oc replace --force -n ${NAMESPACE} -f -

# create database instance from template
oc process \
    -p APP_ID=${APP_ID} \
    -p PG_DATABASE=data \
    -p PG_RESTORE_PATH=${DATA_RESTORE_PATH} \
    -n ${NAMESPACE} \
    crunchydata-single-master-minishift | oc replace --force -n ${NAMESPACE} -f -

oc process \
    -p APP_ID=${APP_ID} \
    -p PG_DATABASE=lob \
    -p PG_RESTORE_PATH=${LOB_RESTORE_PATH} \
    -n ${NAMESPACE} \
    crunchydata-single-master-minishift | oc replace --force -n ${NAMESPACE} -f -


# create backend pipeline from template
oc process \
    -p APP_ID=${APP_ID} \
    jdbcquery-backend-pipeline | oc create -f -
