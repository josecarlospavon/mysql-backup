#!/bin/bash
#
# +-------------------------------------------------------------------------+
#  - Script: mysql_mariadb_backup.sh
#  - Author: JPV
#  - Description: Bash script for backing up MySQL/ MariaDB databases
#  - Version: 1.0
#  - Last Modified: 2024-03-15
# +-------------------------------------------------------------------------+
#
#  /**********************************/
# /*      Loading library           */
#/**********************************/
### Load the logging library. The logingLibV2.sh needs to be located in the lib folder.
. $(dirname $0)/lib/logingLibV2.sh
### Load the oci library that contains utils for machines on OCI
. $(dirname $0)/lib/ocilib.sh
#  /**********************************/
# /*      Loading Configuration     */
#/**********************************/
### Load the configuration, it needs to be located in the cnf folder.
. $(dirname $0)/cnf/mysql_config.conf
#
#  /**********************************/
# /*      Config Section            */
#/**********************************/
# 
### Get year, month and day
YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
TODAY="$(date +'%Y-%m-%d')"
### Remove trailing / for LOG_FILE_BASE_DIR
LOG_FILE_BASE_DIR=${LOG_FILE_BASE_DIR%/}
# Creating log directory
mkdir -p ${LOG_FILE_BASE_DIR}/${YEAR}/${MONTH}
# Create log file and mark start of the script
LOG_FILE=${LOG_FILE_BASE_DIR}/${YEAR}/${MONTH}/${HOSTNAME}_mysqlBCK_log_`date +"%y.%m.%d_%H%M"`.log
setLogFile ${LOG_FILE}
initLogFile

# Check if connected with the right OS user:
printInfo "Checking User OS Account"
if [ ${LOGNAME} != ${USERNAME} ];
then
  printError "Must be connected as ${USERNAME} OS account" && exit 1
fi

# Check if the backup directory exists, and create it if it doesn't
if [ ! -d "$BACKUP_DIR" ]
then
  mkdir -p "$BACKUP_DIR"
fi

printInfo "Getting the list of the databases to backup..."
printSeparator

if [ "${DUMPTYPE}" == "NONSYSTEM" ]; then
  if [ "${MYSQL_USER}" != "root" ]; then
    db=($(mysql -u "${MYSQL_USER}" $([ -n "${MYSQL_PASSWORD}" ] && echo "-p${MYSQL_PASSWORD}") -e "show databases;" | grep -Ev "(Database|information_schema|performance_schema|mysql)" | xargs))
  else
    db=($(mysql -u "${MYSQL_USER}" -e "show databases;" | grep -Ev "(Database|information_schema|performance_schema|mysql)" | xargs))
  fi
elif [ "${DUMPTYPE}" == "ALL" ]; then
  OPT3="--all-databases"
  db=""
elif [ "${DUMPTYPE}" == "SPECIFIC" ]; then
  [ -z "${DBLIST}" ] && echo "DBLIST cannot be empty, exiting" && exit 1
  db=(`printf "%s\n" $DBLIST | xargs`)
else
  printError "Invalid option for DUMPTYPE, exiting" && exit 1
fi

#  /**********************************/
# /*      Database DUMP             */
#/**********************************/
for (( i = 0 ; i < ${#db[@]} ; i++))
do
    printInfo "Starting backup on: ${db[$i]}"
    set -o pipefail
    if [ "${MYSQL_USER}" != "root" ]; then
      if ! mysqldump ${OPT1} ${OPT2} --user=$MYSQL_USER $([ -n "$MYSQL_PASSWORD" ] && echo "-p $MYSQL_PASSWORD") ${OPT3} ${db[$i]} | gzip > "$BACKUP_DIR/${db[$i]}.sql.gz.in_progress"; then
        printError "Failed to produce plain backup database for ${db[$i]}"
      else
        printInfo "Backup completed, renaming file"
        mv $BACKUP_DIR/${db[$i]}.sql.gz.in_progress ${BACKUP_DIR}/${HOSTNAME}_${db[$i]}_`date +"%y.%m.%d_%H%M"`.sql.gz
        if [ "${UPLOAD_OBJ_STORE}" == "YES"]; then
          printInfo "Uploading to object store"
          upload_file ${BACKUP_DIR}/${HOSTNAME}_${db[$i]}_`date +"%y.%m.%d_%H%M"`.sql.gz
        else
          printInfo "Skiping upload to object store"
        fi
      fi
    else  
      if ! mysqldump ${GEN_OPTS} --user=$MYSQL_USER ${DB_OPTS} ${db[$i]} | gzip > "$BACKUP_DIR/${db[$i]}.sql.gz.in_progress"; then
        printError "Failed to produce plain backup database for ${db[$i]}"
      else
        printInfo "Backup completed, renaming file"
        mv $BACKUP_DIR/${db[$i]}.sql.gz.in_progress ${BACKUP_DIR}/${HOSTNAME}_${db[$i]}_`date +"%y.%m.%d_%H%M"`.sql.gz
        if [ "${UPLOAD_OBJ_STORE}" == "YES"]; then
          printInfo "Uploading to object store"
          upload_file ${BACKUP_DIR}/${HOSTNAME}_${db[$i]}_`date +"%y.%m.%d_%H%M"`.sql.gz
        else
          printInfo "Skiping upload to object store"
        fi
      fi
    fi
    set +o pipefail

    MYSQLDUMP_EXIT_CODE=${?}

    if [ ${MYSQLDUMP_EXIT_CODE} != 0 ]; then
      ## Backup failed! Inform and die
      printError "Backup Failed"
    else
      ## Everything OK
      printInfo "Backup Completed sucessfully"
    fi
    printSeparator
done

# +----------------------- END -----------------------+