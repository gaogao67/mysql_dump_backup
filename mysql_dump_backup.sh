#!/bin/bash

##===========================================================================##
## 用户授权脚本：
## GRANT SELECT, RELOAD,SHOW DATABASES, EVENT, LOCK TABLES,REPLICATION CLIENT 
## ON * .* TO 'mysql_backup' @'%' IDENTIFIED BY 'mysql_backup' 
## WITH GRANT OPTION ;
##===========================================================================##
## mysql_backup_type option:
## ONE_BACKUP: backup all user database into one zip file
## MORE_BACKUP: backup user database into different zip files.

##===========================================================================##
## mysql_backup_databases option:
## ALL: backup all user databases
## database_names: backup the specified databases 
##===========================================================================##
## mysql backup config
mysql_exe="/data0/software/mysql/server/bin/mysql"
mysqldump_exe="/data0/software/mysql/server/bin/mysqldump"
mysql_backup_folder="/data0/software/mysql/data/dumps/"
mysql_backup_log="${mysql_backup_folder}mysql_dump_log.txt"
mysql_backup_log_his="${mysql_backup_folder}mysql_dump_log_his.txt"
mysql_backup_host="127.0.0.1"
mysql_backup_port=3306
mysql_backup_user="mysql_backup"
mysql_backup_password="mysql_backup"
mysql_backup_type="MORE_BACKUP"
mysql_backup_databases="mysql_test"
mysql_backup_keep_days=10

##====================================================##
## get mysql version
##====================================================##
function get_mysql_version()
{
    master_version_tmp=`${mysql_exe} \
    --host="${mysql_backup_host}" --port=${mysql_backup_port} \
    --user="${mysql_backup_user}" --password="${mysql_backup_password}" \
    -e "select @@version;"`
    if [[ master_version_tmp == 5.5.* ]]
    then
        mysql_version="mysql55"
    elif [[ master_version_tmp == 5.6.* ]]
    then
        mysql_version="mysql56"
    else
        mysql_version="mysql57"
    fi
}

##===========================================================================##
## remove expired backup file
## keep the backup file of the last N days
function remove_expired_file()
{
    echo "$(date "+%Y-%m-%d %H:%M:%S")  start to remove expired backup file." >> ${mysql_backup_log}
    echo "keep days:    ${mysql_backup_keep_days}" >> ${mysql_backup_log}
    find "${mysql_backup_folder}" -mtime +${mysql_backup_keep_days} -name "*" -exec rm -rf {} \;
    echo "$(date "+%Y-%m-%d %H:%M:%S")  start to mysqldump." >> ${mysql_backup_log}
}

##===========================================================================##
## backup single database
function backup_single_database()
{
    current_database_name=$1
    mysql_backup_file_path="${mysql_backup_folder}""${current_database_name}-`date -I`.sql.gz"
    echo "$(date "+%Y-%m-%d %H:%M:%S")  start to backup database ${current_database_name} to ${mysql_backup_file_path}" >> ${mysql_backup_log} 
    ($mysqldump_exe \
    --host="${mysql_backup_host}" \
    --port=$mysql_backup_port \
    --user="${mysql_backup_user}" \
    --password="${mysql_backup_password}" \
    --databases "${current_database_name}"  \
    --set-gtid-purged=OFF \
    --single-transaction \
    --hex-blob --opt --quick \
    --events --routines --triggers \
    --default-character-set="utf8" \
	--master-data=2 \
    |gzip > "${mysql_backup_file_path}" \
    ) 1>>${mysql_backup_log} 2>>${mysql_backup_log} 

    if [ $? = 0 ]
    then
        echo "$(date "+%Y-%m-%d %H:%M:%S")  backup database ${current_database_name} success." >> ${mysql_backup_log}
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S")  backup database ${current_database_name} failed." >> ${mysql_backup_log}
    fi
}

function backup_more_databases()
{
	echo "$(date "+%Y-%m-%d %H:%M:%S")  databases:${mysql_backup_databases}." >> ${mysql_backup_log}
    for database_name in ${mysql_backup_databases};
    do
        if [ "$database_name" == "" ]
        then
            echo "database name can be empty"
        else
            backup_single_database "${database_name}"
        fi
    done
}

function backup_all_databases()
{
    mysql_backup_file_path="${mysql_backup_folder}""full-backup-`date -I`.sql.gz"
    echo "$(date "+%Y-%m-%d %H:%M:%S")  start to backup all databases to ${mysql_backup_file_path}" >> ${mysql_backup_log}
	echo "databases:${mysql_backup_databases} ."
    ($mysqldump_exe \
    --host="${mysql_backup_host}" \
    --port=$mysql_backup_port \
    --user="${mysql_backup_user}" \
    --password="${mysql_backup_password}" \
    --databases $mysql_backup_databases \
    --set-gtid-purged=OFF \
    --single-transaction \
    --hex-blob --opt --quick \
    --events --routines --triggers \
    --default-character-set="utf8" \
	--master-data=2 \
    |gzip > "${mysql_backup_file_path}" \
    ) 1>>${mysql_backup_log} 2>>${mysql_backup_log} 

    if [ $? = 0 ]
    then
        echo "$(date "+%Y-%m-%d %H:%M:%S")  backup database ${current_database_name} success." >> ${mysql_backup_log}
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S")  backup database ${current_database_name} failed." >> ${mysql_backup_log}
    fi
}


function backup_databases()
{    
	if [ "$mysql_backup_databases" == "ALL" ];
	then
		mysql_backup_databases=`${mysql_exe} --host="${mysql_backup_host}" --port=$mysql_backup_port --user="${mysql_backup_user}" --password="${mysql_backup_password}" -Ne "select concat('''',SCHEMA_NAME,'''') from information_schema.SCHEMATA where SCHEMA_NAME NOT IN ('mysql','information_schema','performance_schema','sys');"|xargs`
	fi
	
    if [ "${mysql_backup_database}" == "ONE_BACKUP" ];
    then
        backup_all_databases
    else
        backup_more_databases
    fi
}


##====================================================##
## 1. dump user script on mysql
## 2. this script only can be used on mysql 5.7
##====================================================##
function dump_user_script_5_7()
{
    script_file_path="${mysql_backup_folder}""user-script-`date -I`.sql"
    echo "$(date "+%Y-%m-%d %H:%M:%S")  start backup user script." >> ${mysql_backup_log}
    (echo "select concat('show create user ''',user,'''@''',host, ''';
    ','show grants for ''',user,'''@''',host, ''';') 
    from mysql.user where user <>'root' and user<>'' and host <> '' " | \
    ${mysql_exe} --host="${mysql_backup_host}" --port=${mysql_backup_port} \
    --user="${mysql_backup_user}" --password="${mysql_backup_password}" -N | \
    ${mysql_exe} --host="${mysql_backup_host}" --port=${mysql_backup_port} \
    --user="${mysql_backup_user}" --password="${mysql_backup_password}" -N | \
    sed "s/$/;/" >> ${script_file_path}) 1>>${mysql_backup_log} 2>>${mysql_backup_log} 
    
    if [ $? = 0 ]
    then
        echo "$(date "+%Y-%m-%d %H:%M:%S")  backup user script success." >> ${mysql_backup_log}
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S")  backup user script failed." >> ${mysql_backup_log}
    fi
}


##====================================================##
## 1. dump user script on mysql
## 2. this script only can be used on mysql 5.5
##====================================================##
function dump_user_script_5_5()
{
    script_file_path="${mysql_backup_folder}""user-script-`date -I`.sql"
    echo "$(date "+%Y-%m-%d %H:%M:%S")  start backup user script." >> ${mysql_backup_log}
    
    (echo "select concat('show grants for ''',user,'''@''',host, ''';')  
    from mysql.user where user <>'root' and user<>'' and host <> '' " | \
    ${mysql_exe} --host="${mysql_backup_host}" --port=${mysql_backup_port} \
    --user="${mysql_backup_user}" --password="${mysql_backup_password}" -N | \
    ${mysql_exe} --host="${mysql_backup_host}" --port=${mysql_backup_port} \
    --user="${mysql_backup_user}" --password="${mysql_backup_password}" -N | \
    sed "s/$/;/" >> ${script_file_path}) 1>>${mysql_backup_log} 2>>${mysql_backup_log} 
    
    if [ $? = 0 ]
    then
        echo "$(date "+%Y-%m-%d %H:%M:%S")  backup user script success." >> ${mysql_backup_log}
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S")  backup user script failed." >> ${mysql_backup_log}
    fi
}

##===========================================================================##

function backup_mysql_user()
{
    if [[ mysql_version == "mysql55" ]]
    then
        dump_user_script_5_5
    else
        dump_user_script_5_7
    fi
}


##===========================================================================##
function mysql_backup()
{
    echo > ${mysql_backup_log}
    get_mysql_version
    remove_expired_file
    backup_databases
    backup_mysql_user
    cat ${mysql_backup_log} > ${mysql_backup_log_his}
}

mysql_backup
