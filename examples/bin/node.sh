#!/bin/bash -eu
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Initialization script for druid nodes
## Runs druid nodes as a daemon
## Environment Variables used by this script -
## DRUID_LIB_DIR - directory having druid jar files, default=lib
## DRUID_CONF_DIR - directory having druid config files, default=conf/druid
## DRUID_LOG_DIR - directory used to store druid logs, default=log
## DRUID_PID_DIR - directory used to store pid files, default=var/druid/pids
## HADOOP_CONF_DIR - directory used to store hadoop config files

usage="Usage: node.sh nodeType (start|stop|status)"

if [ $# -le 1 ]; then
  echo $usage
  exit 1
fi

nodeType=$1
shift

command=$1

LIB_DIR="${DRUID_LIB_DIR:=lib}"
CONF_DIR="${DRUID_CONF_DIR:=conf/druid}"
PID_DIR="${DRUID_PID_DIR:=var/druid/pids}"
WHEREAMI="$(dirname "$0")"
WHEREAMI="$(cd "$WHEREAMI" && pwd)"
JAVA_BIN_DIR="$(source "$WHEREAMI"/java-util && get_java_bin_dir)"

# Remove possilble ending slash
LOG_DIR="${DRUID_LOG_DIR:=${WHEREAMI}/log}"
if [[ $LOG_DIR == */ ]];
then
  LOG_DIR=${LOG_DIR%?}
fi

pid=$PID_DIR/$nodeType.pid

case $command in

  (start)

    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo $nodeType node running as process `cat $pid`.  Stop it first.
        exit 1
      fi
    fi
    if [ ! -d "$PID_DIR" ]; then mkdir -p $PID_DIR; fi
    if [ ! -d "$LOG_DIR" ]; then mkdir -p $LOG_DIR; fi

    if [ -z "$JAVA_BIN_DIR" ]; then
      echo "Could not find java - please run $WHEREAMI/verify-java to confirm it is installed."
      exit 1
    fi
    JAVA="$JAVA_BIN_DIR/java"

    nohup $JAVA -Ddruid.node.type=$nodeType "-Ddruid.log.path=$LOG_DIR" `cat $CONF_DIR/$nodeType/jvm.config | xargs` -cp $CONF_DIR/_common:$CONF_DIR/$nodeType:$LIB_DIR/*:$HADOOP_CONF_DIR org.apache.druid.cli.Main server $nodeType >> /dev/null 2>&1 &
    nodeType_PID=$!
    echo $nodeType_PID > $pid
    echo "Started $nodeType node, pid: $nodeType_PID"
    echo "Logging to default file[$LOG_DIR/$nodeType.log] if no changes made to log4j2.xml"
    ;;

  (stop)

    if [ -f $pid ]; then
      TARGET_PID=`cat $pid`
      if kill -0 $TARGET_PID > /dev/null 2>&1; then
        echo Stopping process `cat $pid`...
        kill $TARGET_PID
      else
        echo No $nodeType node to stop
      fi
      rm -f $pid
    else
      echo No $nodeType node to stop
    fi
    ;;

   (status)
    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo RUNNING
        exit 0
      else
        echo STOPPED
      fi
    else
      echo STOPPED
    fi
    ;;

  (*)
    echo $usage
    exit 1
    ;;
esac
