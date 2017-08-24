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
BACKUP_PV_PATH="${USER_HOME}/minidata/backup"
PGCONF_PV_PATH="${USER_HOME}/minidata/app-pgconf"

oc process \
    -p PG_BACKUP_PV_PATH=${BACKUP_PV_PATH} \
    -p PG_PGCONF_PV_PATH=${PGCONF_PV_PATH} \
    -p PG_PV_GROUP_QUALIFIER=${PV_GROUP_QUALIFIER} \
    minishift-volumes | oc --as system:admin create -f -

echo "Creating Instances"

oc process \
    -p APP_NAME=jdbcquery \
    -p APP_NAME_UPPER=JDBCQUERY \
    -p ARTIFACT_NAME=jdbc-query \
    -p BACKEND_DB_SERVICE=jdbcquery-data \
    -p BACKEND_DB_NAME=nicweb \
    -p BACKEND_DB_SECRET=jdbcquery-dbname-secret \
    -p BACKEND_RESTORE_PATH=skip maven-tomcat-pipeline | oc create -f -

