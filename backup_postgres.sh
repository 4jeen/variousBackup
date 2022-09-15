#!/bin/bash

###
# Backups postgre database and copy archive file to s3 storage
###

###
# file .pgpass
# .pgpass file format:
# hostname:port:database:username:password
# e.g.
# echo "localhost:5432:sammy_db:sammy:1234567890" > .pgpass
# chmod 600 .pgpass
#
# to copy files to S3 storage .s3cfg file must exist in your home dir
###

BACKUP_DIR_NAME="${HOME}/tmp"
NUMBER_OF_DAYS_TO_HOLD_BACKUPS="14"
SQL_DATABASE_NAME="template template2"
SQL_SERVER_NAME="localhost"
SQL_BACKUP_PROG="pg_dump"
S3_BUCKET="postgresql-dump-bucket"
S3_SYNC_PROG="s3cmd"


TMP_FILE=`echo $0|sed  's;[a-zA-Z0-9./]\+\/;;g'`
TMP_FILE="/tmp/${TMP_FILE}.tmp"

backup () {

  if [ ! -f ${HOME}/.pgpass ]; then
		echo ".pgpass file not found in your home dir"
		return 1
  fi
  for NM in ${SQL_DATABASE_NAME};do
    BACKUP_SQL_FILE_NAME=`date +"%Y-%m-%dT%H:%M_${NM}.sql.gz"`
    DELETE_SQL_FILE_NAME=`date +"%Y-%m-%dT%H:??_${NM}.sql.gz" -d "${NUMBER_OF_DAYS_TO_HOLD_BACKUPS} day ago"`
    echo ${NM}
    ${SQL_BACKUP_PROG} -h ${SQL_SERVER_NAME}  ${NM} | gzip  > ${BACKUP_DIR_NAME}/${BACKUP_SQL_FILE_NAME}
    if [ $? -ne 0 ];then
	return $?
    fi
    if [ -e ${HOME}/.s3cfg ]; then
			${S3_SYNC_PROG} put ${BACKUP_DIR_NAME}/${BACKUP_SQL_FILE_NAME}  s3://${S3_BUCKET}/${BACKUP_SQL_FILE_NAME}
    fi

  	if [ -e ${BACKUP_DIR_NAME}/${DELETE_SQL_FILE_NAME} ]; then
  	  	rm ${BACKUP_DIR_NAME}/${DELETE_SQL_FILE_NAME}
  	fi
  	  if [ -e ${HOME}/.s3cfg ] && [ -e ${BACKUP_DIR_NAME}/${DELETE_SQL_FILE_NAME} ]; then
  	  		${S3_SYNC_PROG} rm s3://${S3_BUCKET}/${DELETE_SQL_FILE_NAME}
	  fi
  done
	return $?
}


case $1 in

  "-b")
        if [ -f $TMP_FILE ];then
          echo "Already running,  please wait"
          return 2
        fi
        touch ${TMP_FILE}
        if [ ! -f /tmp/stop_backup ]; then
		  		backup
    			echo $?
    	  fi
    	  if [ -f $TMP_FILE ];then
          rm ${TMP_FILE}
        fi

    ;;

  "-rm")
		s3cmd rm $2
  ;;

  "-get")
		s3cmd get $2 ${BACKUP_DIR_NAME}/$2
  ;;

  "-ls")
	s3cmd ls -r s3://${S3_BUCKET}|egrep  '\.gz|\.bz2'
    ;;


  *)
    	echo -ne "usage\n\t-b backup\n\t-ls list backups\n\t-rm delete backup from s3 storage\n\t-get get backup to tmp\n"
    ;;
esac


