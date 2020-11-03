## 功能说明
对mysqldump命令进行封装，过滤掉系统数据库，仅备份用户数据库和导出用户脚本。

备份时可以指定将多个数据库备份到一个备份文件或多个备份文件。

## 使用帮助
运行前请修改脚本中相关配置参数

## 参数说明
```
##===========================================================================##
## 用户授权脚本：
## GRANT SELECT, RELOAD,SHOW DATABASES, EVENT, LOCK TABLES,REPLICATION CLIENT 
## ON * .* TO 'mysql_backup' @'%' IDENTIFIED BY 'mysql_backup' 
## WITH GRANT OPTION ;

##===========================================================================##
## mysql_backup_type 参数:
## ONE_BACKUP: 将所有数据库备份到一个full-backup-yyyy-MM-dd的备份文件中
## MORE_BACKUP: 将每个数据库备份到单独的database-name-yyyy-MM-dd的备份文件中

##===========================================================================##
## mysql_backup_databases 参数:
## 当mysql_backup_databases被指定为ALL时，备份所有用户数据库，否则备份指定的一个或多个数据库


##===========================================================================##
## only_backup_on_slave 参数:
## 当only_backup_on_slave=1时，仅在从库上备份。

##===========================================================================##
## mysql backup config
mysql_exe="/apps/mysql/server/bin/mysql"
mysqldump_exe="/apps/mysql/server/bin/mysqldump"
mysql_backup_folder="/apps/mysql/data/dumps/"
mysql_backup_log="${mysql_backup_folder}mysql_dump_log.txt"
mysql_backup_log_his="${mysql_backup_folder}mysql_dump_log_his.txt"
mysql_backup_host="127.0.0.1"
mysql_backup_port=3306
mysql_backup_user="mysql_backup"
mysql_backup_password="mysql_backup"
mysql_backup_type="MORE_BACKUP"
mysql_backup_databases="ALL"
mysql_backup_keep_days=30
only_backup_on_slave=1
```

## 相关推荐
- 备份账号仅对本机授权并在本地备份
- 合理设置备份保留周期，条件允许做好异地备份
