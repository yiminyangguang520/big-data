#! /usr/bin/env bash
##########################################################################
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
##########################################################################
#
# run.sh:  Launch a code example from the book "Hadoop in Practice"
#
# Pre-requisites:
# 1)  JAVA_HOME is set
# 2)  HADOOP_HOME is set, and $HADOOP_HOME/conf contains your cluster
#     configuration
#
# If running on a CDH host with standard CDH directory locations in place,
# then you won't need to set HADOOP_HOME.
#
# Use "bash -x bin/run.sh ..." to have bash echo-out all the steps in this
# script for debugging purposes.
#
##########################################################################

# resolve links - $0 may be a softlink
PRG="${0}"

while [ -h "${PRG}" ]; do
  ls=`ls -ld "${PRG}"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "${PRG}"`/"$link"
  fi
done

# check command line args
if [[ $# == 0 ]]; then
  echo "usage: $(basename $0) <example-name>"
  exit 1;
fi


BASEDIR=`dirname ${PRG}`
BASEDIR=`cd ${BASEDIR}/..;pwd`

CDH_HADOOP_HOME=/usr/lib/hadoop

if [ ! -d "${HADOOP_HOME}" ]; then
  if [ -d "${CDH_HADOOP_HOME}" ]; then
    HADOOP_HOME=${CDH_HADOOP_HOME}
    echo "HADOOP_HOME environment not set, but found ${HADOOP_HOME} in path so using that"
  else
    echo "HADOOP_HOME must be set and point to the hadoop home directory"
    exit 2;
  fi
fi

HADOOP_CONF_DIR=${HADOOP_HOME}/conf

if [ ! -d "$HADOOP_CONF_DIR" ]; then

  OLD_HADOOP_CONF=${HADOOP_CONF_DIR}
  HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop

  if [ ! -d "$HADOOP_CONF_DIR" ]; then
    echo "One of $OLD_HADOOP_CONF or $HADOOP_CONF_DIR must exist"
    exit 3;
  fi
fi

echo "Using ${HADOOP_CONF_DIR} as the Hadoop conf directory"

# classpath initially contains $HADOOP_CONF_DIR
CLASSPATH="${HADOOP_CONF_DIR}"

HIP_CODE_JAR=${BASEDIR}/target/hadoop-book-1.0.0-SNAPSHOT-jar-with-dependencies.jar

if [ ! -f "$HIP_CODE_JAR" ]; then
  echo "$HIP_CODE_JAR doesn't exist.  Run 'mvn package' to create this file."
  exit 4;
fi

# add our JAR
CLASSPATH="${CLASSPATH}":${HIP_CODE_JAR}

function add_to_hadoop_core_classpath() {
  dir=$1
  for f in $dir/*.jar; do
    HADOOP_CORE_CLASSPATH=${HADOOP_CORE_CLASSPATH}:$f;
  done

  export HADOOP_CORE_CLASSPATH
}

function add_to_hadoop_extlib_classpath() {
  dir=$1
  for f in $dir/*.jar; do
    HADOOP_EXT_CLASSPATH=${HADOOP_EXT_CLASSPATH}:$f;
  done

  export HADOOP_EXT_CLASSPATH
}

HADOOP_LIB_DIR=$HADOOP_HOME
add_to_hadoop_core_classpath ${HADOOP_LIB_DIR}
HADOOP_LIB_DIR=$HADOOP_HOME/lib
add_to_hadoop_extlib_classpath ${HADOOP_LIB_DIR}

# CDH4
HADOOP_LIB_DIR=/usr/lib/hadoop-hdfs/
add_to_hadoop_core_classpath ${HADOOP_LIB_DIR}

HADOOP_LIB_DIR=/usr/lib/hadoop-yarn
add_to_hadoop_core_classpath ${HADOOP_LIB_DIR}

HADOOP_LIB_DIR=/usr/lib/hadoop-0.20-mapreduce
add_to_hadoop_core_classpath ${HADOOP_LIB_DIR}


if [ "${HIP_USE_MVN_HADOOP}" != "" ]; then
  export CLASSPATH=${CLASSPATH}:${HADOOP_CORE_CLASSPATH}:${HADOOP_EXT_CLASSPATH}:${HADOOP_CLASSPATH}
else
  export CLASSPATH=${HADOOP_CORE_CLASSPATH}:${HADOOP_EXT_CLASSPATH}:${HADOOP_CLASSPATH}:${CLASSPATH}
fi

JAVA=$JAVA_HOME/bin/java
JAVA_HEAP_MAX=-Xmx512m

if [ ! -f "$JAVA" ]; then
  echo "JAVA_HOME is not set or doesn't point to a valid directory."
  exit 5;
fi

# pick up the native Hadoop directory if it exists
# this is to support native compression codecs
#
if [ -d "${HADOOP_HOME}/build/native" -o -d "${HADOOP_HOME}/lib/native" -o -d "${HADOOP_HOME}/sbin" ]; then
  JAVA_PLATFORM=`CLASSPATH=${CLASSPATH} ${JAVA} -Xmx32m org.apache.hadoop.util.PlatformName | sed -e "s/ /_/g"`

  if [ -d "$HADOOP_HOME/build/native" ]; then
    if [ "x$JAVA_LIBRARY_PATH" != "x" ]; then
        JAVA_LIBRARY_PATH=${JAVA_LIBRARY_PATH}:${HADOOP_HOME}/build/native/${JAVA_PLATFORM}/lib
    else
        JAVA_LIBRARY_PATH=${HADOOP_HOME}/build/native/${JAVA_PLATFORM}/lib
    fi
  fi

  if [ -d "${HADOOP_HOME}/lib/native" ]; then
    if [ "x$JAVA_LIBRARY_PATH" != "x" ]; then
      JAVA_LIBRARY_PATH=${JAVA_LIBRARY_PATH}:${HADOOP_HOME}/lib/native/${JAVA_PLATFORM}
    else
      JAVA_LIBRARY_PATH=${HADOOP_HOME}/lib/native/${JAVA_PLATFORM}
    fi
  fi
fi

# echo $CLASSPATH
# echo ${JAVA_LIBRARY_PATH}

# echo "HADOOP_LIB_DIR=${HADOOP_LIB_DIR}"
# echo "JAVA_LIBRARY_PATH=${JAVA_LIBRARY_PATH}"
# echo "HADOOP_CORE_CLASSPATH=${HADOOP_CORE_CLASSPATH}"
# echo "HADOOP_EXT_CLASSPATH=${HADOOP_EXT_CLASSPATH}"

# CLASSPATH="/etc/hadoop/conf:/usr/lib/hadoop/lib/*:/usr/lib/hadoop/.//*:/usr/lib/hadoop-hdfs/./:/usr/lib/hadoop-hdfs/lib/*:/usr/lib/hadoop-hdfs/.//*:/usr/lib/hadoop-yarn/.//*:/usr/lib/hadoop-0.20-mapreduce/./:/usr/lib/hadoop-0.20-mapreduce/lib/*:/usr/lib/hadoop-0.20-mapreduce/.//*:${HIP_CODE_JAR}"

# echo "$JAVA" $JAVA_HEAP_MAX -Djava.library.path=${JAVA_LIBRARY_PATH} -classpath "$CLASSPATH" "$@"

"$JAVA" $JAVA_HEAP_MAX -Djava.library.path=${JAVA_LIBRARY_PATH} -classpath "$CLASSPATH" "$@"
