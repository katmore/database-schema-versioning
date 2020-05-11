#!/usr/bin/env bash
# Mongo database migration utility compliant with 'db-schema-spec' v1.1.2 (https://github.com/katmore/database-schema-versioning)
#
ME_USAGE="[-hua][<options...>] <DB-SCHEMA> <DB-NAME> [<mongo command args...>]"
ME_ABOUT="Mongo database migration utility compliant with 'db-schema-spec' v1.1.2 (https://github.com/katmore/database-schema-versioning)"
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
MONGO_CMD=mongo
USE_FLAT_CONFIG=0
MONGO_OPTS=" --quiet"
#
# option values
#
ABOUT_MODE=0
USAGE_MODE=0
HELP_MODE=0
CUSTOM_MONGO_CMD=0
DEFAULT_SCHEMA_ROOT=$SCHEMA_ROOT
CUSTOM_SCHEMA_ROOT=0
DEFAULT_MONGO_CMD=$MONGO_CMD
USE_FLAT_CONFIG=0
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
           mongo-cmd=*)MONGO_CMD=$LONG_OPTARG; CUSTOM_MONGO_CMD=1 ;;
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
   echo " --mongo-cmd=<mongo-cmd>"
   echo "   Specify mongo command to use."
   echo "   Default: $DEFAULT_MONGO_CMD"
   echo ""
   echo "arguments:"
   echo " <DB-SCHEMA>"
   echo " The directory name containing the 'schema.json' file within the --schema-root to reference for performing database migration."
   echo " <DB-NAME>"
   echo " Optionally specify name of the mongo database to supply to the mongo command when peforming database migration."
   echo " <mongo command args...>"
   echo " Optionally specify extra arguments to be supplied each time mongo command is executed when peforming database migration."
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
# enforce mongo-cmd dependency
#
hash "$MONGO_CMD" > /dev/null 2>&1 || {
   if [ "$CUSTOM_MONGO_CMD" = "1" ]; then
       >&2 echo -e "$ME_NAME: failed dependency check for specified --mongo-cmd '$MONGO_CMD', command is missing or inaccessible"
       exit 2
   fi
   >&2 echo -e "$ME_NAME: failed dependency check for '$MONGO_CMD', command is missing or inaccessible"
   exit 1
}
#
# enforce other dependencies
#
DEPENDENCY_SET=(jq)
DEPENDENCY_STATUS=0
for DEP_CMD in "${DEPENDENCY_SET[@]}"
do
   hash $DEP_CMD > /dev/null 2>&1
   DEP_STATUS=$?
   if [ "$DEP_STATUS" -ne "0" ]; then
      >&2 echo -e "$ME_NAME: failed dependency check for '$DEP_CMD', command is missing or inaccessible"
      DEPENDENCY_STATUS=1
   fi
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
   echo -e $ME_USAGE
   exit 2
}
shift
#
# concat mongo command
#
if [ ! -z "$@" ]; then
   MONGO_CMD="$MONGO_CMD $MONGO_OPTS $@ $DB_NAME"
else
   MONGO_CMD="$MONGO_CMD $MONGO_OPTS $DB_NAME"
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
if [ ! -f $SCHEMA_JSON ]; then
   >&2 echo -e "$ME_NAME: 'schema.json' file is missing from the corresponding <DB-SCHEMA> directory in <SCHEMA-ROOT-PATH>. <DB-SCHEMA>: $DB_SCHEMA, <SCHEMA-ROOT-PATH>: $SCHEMA_ROOT"
   echo -e "\n$ME_USAGE"
   exit 1
fi
#
# sanity check schema 'type' (schema.json.system)
#
SCHEMA_TYPE=$(jq -er '.system' $SCHEMA_JSON)
CMD_STATUS=$?
if [ "$CMD_STATUS" -ne "0" ]; then
   >&2 echo "$ME_NAME: .system JSON parse failed using file: $SCHEMA_JSON"
   echo -e "\n$ME_USAGE"
   exit 1
fi
if [ "$SCHEMA_TYPE" != "mongo" ]; then
   >&2 echo "$ME_NAME: this script can only process schema type 'mongo', instead found type '$SCHEMA_TYPE' for the '$DB_SCHEMA' schema (from file '$SCHEMA_JSON')"
   echo -e "\n$ME_USAGE"
   exit 1
fi
#
# determine the 'latest version'
#
LATEST_VERSION=$(jq -re '.["latest-version"]' $SCHEMA_JSON)
CMD_STATUS=$?
if [ "$CMD_STATUS" -ne "0" ]; then
   >&2 echo "$ME_NAME: failed to process 'latest-version' from schema.json: $SCHEMA_JSON"
   echo -e "\n$ME_USAGE"
   exit 1
fi
#
# create 'db_schema_revision' collection if needed
#
#REVISION_COLLECTION_JS='CREATE COLLECTION IF NOT EXISTS `db_schema_revision` ( `version` varchar(20) COLLATE utf8_bin NOT NULL, `active` tinyint(4) NOT NULL DEFAULT '0', `source` tinytext COLLATE utf8_bin NOT NULL, `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY `version` (`version`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin'
REVISION_COLLECTION_JS='db.db_schema_revision.ensureIndex({"version":1},{"unique":true});'
CMD_OUT=$($MONGO_CMD --eval=$REVISION_COLLECTION_JS 2>&1)
CMD_STATUS=$?
if [ "$CMD_STATUS" -ne "0" ]; then
   >&2 echo -e "mongo: $CMD_OUT"
   >&2 echo "$ME_NAME: db_schema_revision collection check failed"
   echo "#"
   echo "#(create the 'db_schema_revision' collection if needed)"
   echo "#"
   echo -e "$REVISION_COLLECTION_JS"
   echo "#"
   echo -e "$ME_USAGE"
   exit 1
fi

#
# determine the 'deployed version'
#
DEPLOYED_VERSION_JS='db.db_schema_revision.find({"active":true},{version:1,active:1,_id:0}).sort({"version":-1}).limit(1);'
#DEPLOYED_VERSION_CMD="$MONGO_CMD--eval='$DEPLOYED_VERSION_JS'"
DEPLOYED_VERSION_RAW=$($MONGO_CMD --eval=$DEPLOYED_VERSION_JS 2>&1)
CMD_STATUS=$?
if [ "$CMD_STATUS" -ne "0" ]; then
   >&2 echo "$ME_NAME: unable to determine the 'DEPLOYED_VERSION'"
   echo "#"
   echo "#(create the 'db_schema_revision' collection if needed)"
   echo "#"
   echo -e "$REVISION_COLLECTION_JS"
   
   SECOND_NEWEST_VERSION=$(jq '.["version-history"]' $SCHEMA_JSON | jq 'keys' | jq -re .[length-2])
   CMD_STATUS=$?
   if [ "$CMD_STATUS" -ne "0" ]; then
      >&2 echo "$ME_NAME: .version-history JSON parse failed using file: $SCHEMA_JSON"
      echo -e "\n$ME_USAGE"
      exit 1
   fi
   if [ "$SECOND_NEWEST_VERSION" = "null" ]; then
      >&2 echo "$ME_NAME: unable to determine a fallback 'DEPLOYED_VERSION' from schema.json: $SCHEMA_JSON"
      echo -e "\n$ME_USAGE"
      exit 1
   fi
   UPDATE_REVISION_JS='db.db_schema_revision.findOneAndUpdate({"version":"1.0"},{$set:{"version":"1.0","active" : true, "source" : "manual"}},{upsert:true});'
   
   echo "the 'second newest' schema version is $SECOND_NEWEST_VERSION"
   echo "to initialize the database as having version 1.0, execute the following JS statements..."
   echo "---"
   echo "---BEGIN 'db_schema_revision' INITIALIZATION JS statements>>>"
   echo "---"
   
   echo "#"
   echo "#(insert DB revision)"
   echo "#"
   echo -e "$UPDATE_REVISION_JS"
   echo "---"
   echo "---<<< END 'db_schema_revision' INITIALIZATION JS statements"
   echo "---"
   echo -e "to use a version other than \"1.0\", modify\n{... \"version\":\"<MY-CURRENT-VERSION>\", ...}\nin the 2nd JS command above (insert DB revision)'"
   exit 1
fi
#echo "DEPLOYED_VERSION_CMD: $DEPLOYED_VERSION_CMD"
#echo "DEPLOYED_VERSION_RAW: $DEPLOYED_VERSION_RAW"
#exit 2

DEPLOYED_VERSION=$(echo "$DEPLOYED_VERSION_RAW" | jq -re '.version') || {
  CMD_STATUS=$?
  >&2 echo "$ME_NAME: failed to parse JSON to get current schema version of database"
  exit $CMD_STATUS
}
#echo "DEPLOYED_VERSION: $DEPLOYED_VERSION"
#exit 2
#
# if unable to determine the 'deployed version',
#   display JS statement suggestions and exit with error status
#
if [ -z "$DEPLOYED_VERSION" ]; then
   >&2 echo "$ME_NAME: (internal error) missing DEPLOYED_VERSION from db_schema_revision"
   exit 1
fi
#
# exit if 'deployed version' is same as 'latest version'
#
if [ "$DEPLOYED_VERSION" = "$LATEST_VERSION" ]; then
   echo "database schema '$DB_SCHEMA' is already at latest-version: $LATEST_VERSION"
   exit 0
fi
echo "latest-version: $LATEST_VERSION"
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
   CHECK_VER=$(jq -re '.["version-history"] | keys | .[$CHECK_VER_IDX]' "$SCHEMA_JSON")
   CMD_STATUS=$?
   if [ "$CMD_STATUS" -ne "0" ]; then
      >&2 echo "$ME_NAME: .version-history[$CHECK_VER_IDX] JSON parse failed using file: $SCHEMA_JSON"
      echo -e "\n$ME_USAGE"
      exit 1
   fi
   #
   # jq command outputs "null" if
   #   CHECK_VER_IDX is out of bounds
   #   (therefore, loop is done)
   #
   if [ "$CHECK_VER" = "null" ]; then
      break
   fi
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
      VERSION_DIR=$(jq '.["version-history"]' $SCHEMA_JSON | jq -re '.["'$CHECK_VER'"]')
      VERSION_JSON=$SCHEMA_DIR/$VERSION_DIR/version.json
      JS_IDX=0
      LAST_MONGO_STATUS
      #
      # js-command loop:
      #   loop to execute each command
      #   file in the array:
      #      version.json.js-command
      #
      #readarray -t JS_COMMAND < <(jq '.["js-command"]' $VERSION_JSON | jq -re -c '.[]')
      #for js_file_basename in "${JS_COMMAND[@]}"; do
      while IFS= read -r js_file_basename; do
         JS_FILE=$SCHEMA_DIR/$VERSION_DIR/$js_file_basename
         #echo "JS_FILE: $JS_FILE"
         if [ ! -f $JS_FILE ]; then
            >&2 echo "$ME_NAME: js-command file '$js_file_basename' not found, from version.json.['js-command']["$JS_IDX"], JS_FILE: $JS_FILE"
            exit 1
         fi
         echo "$ME_NAME: executing version $CHECK_VER js-command: $VERSION_DIR/$js_file_basename"
         REVISION_CMD="$MONGO_CMD $JS_FILE"
         #echo "REVISION_CMD: $REVISION_CMD"
         CMD_OUT=$($REVISION_CMD 2>&1)
         LAST_MONGO_STATUS=$?
         if [ "$LAST_MONGO_STATUS" -ne "0" ]; then
            >&2 echo -e "mongo: $CMD_OUT"
            >&2 echo "$ME_NAME: mongo error while executing js-command '$js_file_basename', from version.json.['js-command']["$JS_IDX"], JS_FILE: $JS_FILE"
            exit 1
         fi
         #echo "REVISION_CMD OUTPUT: $CMD_OUT"
         ((JS_IDX++))
      done < <(jq '.["js-command"]' $VERSION_JSON | jq -re -c '.[]')
      [ "$LAST_MONGO_STATUS" = "0" ] || {
        >&2 echo "$ME_NAME: failed processing version: $VERSION_JSON"
        exit 1
      }
      DEPLOYED_VERSION=$CHECK_VER
      echo "setting active version to $DEPLOYED_VERSION"
      UPDATE_REVISION_JS='db.db_schema_revision.findOneAndUpdate({"version":"'$DEPLOYED_VERSION'"},{$set:{"version":"'$DEPLOYED_VERSION'","active":true,"source":"migrate-mongo"}},{"upsert":true});db.db_schema_revision.update({"version":{$ne:"'$DEPLOYED_VERSION'"}},{$set:{"active":false}},{"multi":true});'
      #CMD_OUT=$(echo $UPDATE_REVISION_JS | "${@:2}"$MONGO_OPTS 2>&1)
      CMD_OUT=$($MONGO_CMD --eval=$UPDATE_REVISION_JS 2>&1)
      CMD_STATUS=$?
      if [ "$CMD_STATUS" -ne "0" ]; then
         >&2 echo -e "mongo: $CMD_OUT"
         >&2 echo "$ME_NAME: mongo error while updating 'db_schema_revision' collection with DEPLOYED_VERSION: $DEPLOYED_VERSION"
         exit 1
      fi
   fi
   if [ "$CHECK_VER" = "$DEPLOYED_VERSION" ]; then
      DO_NEXT_VER_CMDS=1
   fi
   ((CHECK_VER_IDX++))
done #END version-history loop

echo "database has been successfully migrated to latest version: $DEPLOYED_VERSION"
