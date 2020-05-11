#!/usr/bin/env bash
# MySQL database migration utility compliant with 'db-schema-spec' v1.1.2 https://github.com/katmore/database-schema-versioning
#
ME_USAGE="[-hua][<options...>] <DB-SCHEMA> <DB-NAME> [<mysql command args...>]"
ME_ABOUT="MySQL database migration utility compliant with 'db-schema-spec' v1.1.2 https://github.com/katmore/database-schema-versioning"
ME_COPYRIGHT="(c) 2011-2020 Doug Bird. All Rights Reserved. This is free software released under the MIT and GPL licenses."
#
# localization
#
ME_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$ME_SOURCE" ]; do # resolve $ME_SOURCE until the file is no longer a symlink
  ME_DIR="$( cd -P "$( dirname "$ME_SOURCE" )" && pwd )"
  ME_SOURCE="$(readlink "$ME_SOURCE")"
  [[ $ME_SOURCE != /* ]] && ME_SOURCE="$ME_DIR/$ME_SOURCE" # if $ME_SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
ME_DIR="$( cd -P "$( dirname "$ME_SOURCE" )" && pwd )"
ME_NAME=$(basename "$ME_SOURCE")
#
# default configuration
#
SCHEMA_ROOT="$PWD"
MYSQL_CMD=mysql
#
# option values
#
ABOUT_MODE=0
USAGE_MODE=0
HELP_MODE=0
CUSTOM_MYSQL_CMD=0
DEFAULT_SCHEMA_ROOT=$SCHEMA_ROOT
CUSTOM_SCHEMA_ROOT=0
DEFAULT_MYSQL_CMD=$MYSQL_CMD
#
# parse options
#
OPTION_STATUS=0
while getopts :uhav-: arg; do
  case $arg in
    u ) USAGE_MODE=1 ;;
    h ) HELP_MODE=1 ;;
    a ) ABOUT_MODE=1 ;;
    v ) USAGE_MODE=1 ;;
    - )  LONG_OPTARG="${OPTARG#*=}"
         case $OPTARG in
           help )  HELP_MODE=1 ;;
           usage )  USAGE_MODE=1 ;;
           about )  ABOUT_MODE=1 ;;
           version ) ABOUT_MODE=1 ;;
           mysql-cmd=*)MYSQL_CMD=$LONG_OPTARG; CUSTOM_MYSQL_CMD=1 ;;
           schema-root=*)SCHEMA_ROOT=$LONG_OPTARG; CUSTOM_SCHEMA_ROOT=1 ;;
           '' )        break ;; # "--" terminates argument processing
           * )         echo "$ME_NAME: unknown option --$OPTARG" >&2; OPTION_STATUS=2 ;;
         esac ;;
    * )  echo "$ME_NAME: unknown option -$OPTARG" >&2; OPTION_STATUS=2 ;;
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list
if [ "$OPTION_STATUS" -ne "0" ]; then
   >&2 echo "$ME_NAME: one or more invalid options"
   echo -e $ME_USAGE
   exit $OPTION_STATUS
fi
#
# about mode
#
[ "$ABOUT_MODE" -eq "1" ] && {
   echo -e "$ME_NAME"
   echo -e "$ME_COPYRIGHT"
   echo ""
   echo -e "$ME_ABOUT"
   exit 0
}
#
# help mode
#
[ "$HELP_MODE" -eq "1" ] && {
   echo -e "$ME_NAME"
   echo -e "$ME_COPYRIGHT"
   echo ""
   echo -e "usage:\n   $ME_NAME $ME_USAGE"
   echo ""
   echo "options:"
   echo " --schema-root=<SCHEMA-ROOT-PATH>"
   echo "   Specify path to the schema root directory."
   echo "   Default: $DEFAULT_SCHEMA_ROOT"
   echo " --mysql-cmd=<MYSQL-CMD>"
   echo "   Specify mysql command to use."
   echo "   Default: $DEFAULT_MYSQL_CMD"
   echo ""
   echo "arguments:"
   echo " <DB-SCHEMA>"
   echo " The directory name containing the 'schema.json' file within the --schema-root to reference for performing database migration."
   echo " <DB-NAME>"
   echo " Optionally specify name of the mysql database to supply to the mysql command when peforming database migration."
   echo " <mysql command args...>"
   echo " Optionally specify extra arguments to be supplied each time mysql command is executed when peforming database migration."
   exit 0
}
#
# usage mode
#
if [ "$USAGE_MODE" -eq "1" ]; then
   echo -e "usage:\n $ME_NAME $ME_USAGE"
   exit 0
fi
#
# enforce mysql-cmd dependency
#
hash "$MYSQL_CMD" > /dev/null 2>&1 || {
   if [ "$CUSTOM_MYSQL_CMD" = "1" ]; then
       >&2 echo -e "$ME_NAME: failed dependency check for specified --mysql-cmd '$MYSQL_CMD', command is missing or inaccessible"
       exit 2
   fi
   >&2 echo -e "$ME_NAME: failed dependency check for '$MYSQL_CMD', command is missing or inaccessible"
   exit 1
}
#
# enforce other dependencies
#
DEPENDENCY_SET=(jq)
DEPENDENCY_STATUS=0
for DEP_CMD in "${DEPENDENCY_SET[@]}"
do
   hash $DEP_CMD > /dev/null 2>&1 || {
      >&2 echo -e "$ME_NAME: failed dependency check for '$DEP_CMD', command is missing or inaccessible"
      DEPENDENCY_STATUS=1
    }
done
if [ "$DEPENDENCY_STATUS" -ne "0" ]; then
   >&2 echo -e "$ME_NAME: one or more dependency checks failed"
   exit 1
fi
#
# <DB-SCHEMA> positional arg
#
DB_SCHEMA=$1
[ -n "$DB_SCHEMA" ] || {
   >&2 echo -e "$ME_NAME: missing <DB-SCHEMA>"
   echo -e $ME_USAGE
   exit 2
}
shift
DB_NAME=$1
[ -n "$DB_NAME" ] || {
   >&2 echo -e "$ME_NAME: missing <DB-NAME>"
   echo -e $ME_NAME $ME_USAGE
   exit 2
}
shift
#
# concat mysql command
#
if [ -n "$@" ]; then
   MYSQL_CMD="$MYSQL_CMD $@ $DB_NAME"
else
   MYSQL_CMD="$MYSQL_CMD $DB_NAME"
fi
#
# sanity check $SCHEMA_ROOT
#
if [ ! -d $SCHEMA_ROOT ]; then
   [ "$CUSTOM_SCHEMA_ROOT" = "1" ] && {
     >&2 echo -e "$ME_NAME: the --schema-root does not exist: $SCHEMA_ROOT"
     exit 2
   }
   >&2 echo -e "$ME_NAME: the default SCHEMA-ROOT-PATH does not exist: $SCHEMA_ROOT"
   exit 1
fi
#
# sanity check $SCHEMA_DIR
#
SCHEMA_DIR=$SCHEMA_ROOT/$DB_SCHEMA
if [ ! -d $SCHEMA_DIR ]; then
   if [ "$CUSTOM_SCHEMA_ROOT" = "1" ]; then
       SCHEMA_ROOT_LABEL="the --schema-root specified ($SCHEMA_ROOT)"
   else
       SCHEMA_ROOT_LABEL="the default SCHEMA-ROOT-PATH ($SCHEMA_ROOT)"
   fi
   >&2 echo -e "$ME_NAME: the <DB-SCHEMA> directory '$DB_SCHEMA' does not exist in $SCHEMA_ROOT_LABEL."
   exit 2
fi
SCHEMA_JSON="$SCHEMA_DIR/schema.json"
[ -f "$SCHEMA_JSON" ] || {
   >&2 echo -e "$ME_NAME: 'schema.json' file is missing from the corresponding <DB-SCHEMA> directory in <SCHEMA-ROOT-PATH>. <DB-SCHEMA>: $DB_SCHEMA, <SCHEMA-ROOT-PATH>: $SCHEMA_ROOT"
   echo -e "\n$ME_NAME $ME_USAGE"
   exit 1
}

[ -r "$SCHEMA_JSON" ] || {
   >&2 echo -e "$ME_NAME: missing read permission for 'schema.json' file: $SCHEMA_JSON" 
   exit 1
}
#
# sanity check schema 'type' (schema.json.system)
#
SCHEMA_SYSTEM=$(jq -er '.system' $SCHEMA_JSON) || {
   >&2 echo "$ME_NAME: .system JSON parse failed using file: $SCHEMA_JSON"
   exit 1
}
if [ "$SCHEMA_SYSTEM" != "mysql" ]; then
   >&2 echo "$ME_NAME: this script can only process the schema for system 'mysql', instead found system '$SCHEMA_SYSTEM' for the '$DB_SCHEMA' schema (from file '$SCHEMA_JSON')"
   exit 1
fi
#
# determine the 'latest version'
#
LATEST_VERSION=$(jq -er '.["current-version"]' $SCHEMA_JSON) || {
   >&2 echo "$ME_NAME: .current-version JSON parse failed using file: $SCHEMA_JSON"
   exit 1
}

#
# create 'db_schema_revision' table if needed
#
REVISION_TABLE_SQL='CREATE TABLE IF NOT EXISTS `db_schema_revision` ( `version` varchar(20) COLLATE utf8_bin NOT NULL, `active` tinyint(4) NOT NULL DEFAULT '0', `source` tinytext COLLATE utf8_bin NOT NULL, `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY `version` (`version`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin'
CMD_OUT=$(echo $REVISION_TABLE_SQL | $MYSQL_CMD 2>&1) || {
   >&2 echo -e "mysql: $CMD_OUT"
   >&2 echo "$ME_NAME: db_schema_revision table check failed"
   exit 1
}
#
# determine the 'deployed version'
#
DEPLOYED_VERSION_SQL='SELECT version FROM db_schema_revision WHERE active=1 ORDER BY version DESC LIMIT 1'
DEPLOYED_VERSION=$(echo $DEPLOYED_VERSION_SQL | $MYSQL_CMD -N 2> /dev/null) || {
   >&2 echo "$ME_NAME: failed to obtain db_schema_revision"
   exit 1
}
#
# if unable to determine the 'deployed version', 
#   display SQL statement suggestions and exit with error status
#
if [ -z "$DEPLOYED_VERSION" ]; then
   >&2 echo "$ME_NAME: (WARNING) the 'DEPLOYED_VERSION' could not be found in the database using table 'db_schema_revision'"
   SECOND_NEWEST_VERSION=$(jq -er '.["version-history"] | keys | .[length-2]' "$SCHEMA_JSON") || {
      >&2 echo "$ME_NAME: unable to determine a fallback 'DEPLOYED_VERSION' from schema.json: $SCHEMA_JSON"
      exit 1
   }
   UPDATE_REVISION_SQL="INSERT INTO\ndb_schema_revision\nSET\nversion='$SECOND_NEWEST_VERSION',\nactive=1,\nsource='manual'\nON DUPLICATE KEY UPDATE\nactive=1,\nsource='migrate-mysql'"
   >&2 echo "$ME_NAME: unable to determine the 'DEPLOYED_VERSION'"
   echo "the 'second newest' schema version is $SECOND_NEWEST_VERSION"
   echo "to initialize the database as having version $SECOND_NEWEST_VERSION, execute the following SQL statements..."
   echo "---"
   echo "---BEGIN 'db_schema_revision' INITIALIZATION SQL statements>>>"
   echo "---"
   echo "#"
   echo "#(create the 'db_schema_revision' table if needed)"
   echo "#"
   echo -e "$REVISION_TABLE_SQL;"
   echo "#"
   echo "#(insert DB revision)"
   echo "#"
   echo -e "$UPDATE_REVISION_SQL;"
   echo "---"
   echo "---<<< END 'db_schema_revision' INITIALIZATION SQL statements"
   echo "---"
   echo -e "to use a version other than \"$SECOND_NEWEST_VERSION\", modify the line\n\"version='{MY-CURRENT-VERSION}'\"\nin the 2nd SQL statement above (insert DB revision)'"
   exit 1
fi
#
# exit if 'deployed version' is same as 'latest version'
#
if [ "$DEPLOYED_VERSION" = "$LATEST_VERSION" ]; then
   echo "database schema '$DB_SCHEMA' is already at current-version: $LATEST_VERSION"
   exit 0
fi
echo "current-version: $LATEST_VERSION"
echo "deployed version: $DEPLOYED_VERSION"
#
# prepare for schema.json loop
#
CHECK_VER_IDX=0 #current IDX of .version-history hashmap
DO_NEXT_VER_CMDS=0 #flag to execute the revision commands
#
# version-history loop:
#   loop through schema.json.version-history: 
#      find current current version;
#         and go to the very next, 
#         (and next, and next, etc.) 
#         until "caught up"
#
while :
do
   #
   # parse schema.json to check 'next' version
   #
   #CHECK_VER=$(jq -e '.["version-history"]' $SCHEMA_JSON | jq -e keys | jq -r '.['$CHECK_VER_IDX']') || {
   CHECK_VER=$(jq -er '.["version-history"] | keys | sort_by(tonumber) | .['$CHECK_VER_IDX']' "$SCHEMA_JSON") || {
     #
     # jq command outputs "null" if
     #   CHECK_VER_IDX is out of bounds
     #   (therefore, loop is done)
     #
     if [ "$CHECK_VER" = "null" ]; then
        break
     fi
     >&2 echo "$ME_NAME: .[\"version-history\"][$CHECK_VER_IDX] (VER_IDX) JSON parse failed using file: $SCHEMA_JSON"
     echo -e "\n$ME_USAGE"
     exit 1
   }

   #
   # if $DO_NEXT_VER_CMDS flag is on...
   #   execute revision commands
   #
   if [ "$DO_NEXT_VER_CMDS" -eq "1" ]; then
      #
      # determine the path to the 
      #    version.json file for the 
      #    current version (within this 
      #    loop)
      #
      VERSION_DIR=$(jq -er '.["version-history"] | .["'$CHECK_VER'"]' $SCHEMA_JSON) || {
        >&2 echo "$ME_NAME: .[\"version-history\"][$CHECK_VER_IDX] JSON parse failed using file: $SCHEMA_JSON"
        echo -e "\n$ME_USAGE"
        exit 1
      }
      VERSION_JSON=$SCHEMA_DIR/$VERSION_DIR/version.json
      SQL_IDX=0
      LAST_MYSQL_STATUS=
      #
      # sql-command loop:
      #   loop to execute each command 
      #   file in the array:
      #      version.json.sql-command
      #
      #for sql_file_basename in "${SQL_COMMAND[@]}"; do
      jq -erc '.["sql-command"] | .[]' "$VERSION_JSON" |
        while IFS= read -r sql_file_basename; do
           SQL_FILE=$SCHEMA_DIR/$VERSION_DIR/$sql_file_basename
           echo "SQL_FILE: $SQL_FILE"
           if [ ! -f $SQL_FILE ]; then
              >&2 echo "$ME_NAME: sql-command file '$sql_file_basename' not found, from version.json.['sql-command']["$SQL_IDX"], SQL_FILE: $SQL_FILE"
              exit 1
           fi
           echo "executing version $CHECK_VER sql-command: $VERSION_DIR/$sql_file_basename"
           CMD_OUT=$($MYSQL_CMD < $SQL_FILE 2>&1)
           LAST_MYSQL_STATUS=$?
           if [ "$LAST_MYSQL_STATUS" -ne "0" ]; then
              >&2 echo -e "mysql: $CMD_OUT"
              >&2 echo "$ME_NAME: mysql error while executing sql-command '$sql_file_basename', from version.json.['sql-command']["$SQL_IDX"], SQL_FILE: $SQL_FILE"
              exit 1
           fi
           ((SQL_IDX++))
        done
      [ "$LAST_MYSQL_STATUS" = "0" ] || {
        >&2 echo "$ME_NAME: error processing version JSON: $VERSION_JSON"
        exit 1
      }
      #
      # update the table
      #   'db_schema_revision' with the
      #   version just applied (in this 
      #   loop)
      #
      DEPLOYED_VERSION=$CHECK_VER
      echo "setting active version to $DEPLOYED_VERSION"
      UPDATE_REVISION_SQL="INSERT INTO db_schema_revision SET version='$DEPLOYED_VERSION',active=1,source='migrate-mysql' ON DUPLICATE KEY UPDATE active=1,source='migrate-mysql';UPDATE db_schema_revision SET active=0 WHERE version <> '$DEPLOYED_VERSION';"
      CMD_OUT=$(echo $UPDATE_REVISION_SQL | $MYSQL_CMD 2>&1)
      CMD_STATUS=$?
      if [ "$CMD_STATUS" -ne "0" ]; then
         >&2 echo -e "mysql: $CMD_OUT"
         >&2 echo "$ME_NAME: mysql error while updating 'db_schema_revision' table with DEPLOYED_VERSION: $DEPLOYED_VERSION"
         #echo -e "\n$ME_USAGE"
         exit 1
      fi
   fi
   echo CHECK_VER: $CHECK_VER
   echo DEPLOYED_VERSION: $DEPLOYED_VERSION
   if [ "$CHECK_VER" = "$DEPLOYED_VERSION" ]; then
     echo DO_NEXT_VER_CMDS
      DO_NEXT_VER_CMDS=1
   fi
   ((CHECK_VER_IDX++))
done #END version-history loop

echo "database has been successfully migrated to latest version: $DEPLOYED_VERSION"






