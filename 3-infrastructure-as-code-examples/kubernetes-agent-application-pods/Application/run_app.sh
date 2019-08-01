#!/bin/sh

MYAPP_CTR=${LOOPCTR}
SLEEP_TIME=${STIME}

if [ -z "$SLEEP_TIME" ]
then
   SLEEP_TIME=30
fi

echo Sleep Time set to $SLEEP_TIME

# Get the container ID and hostname. Combine them to get the agent alias
CID=$(cat /proc/1/cgroup | grep 'docker/' | tail -1 | sed 's/^.*\///' | cut -c 1-12)

echo Container ID is $CID

# loop LOOPCTR times and quit

echo Counting from ${LOOPCTR}

while [ $MYAPP_CTR -gt 0 ]; do
  MYAPP_CTR=$((MYAPP_CTR-1));
  echo ..at $MYAPP_CTR
  sleep $SLEEP_TIME
done

echo All done counting
exit 0
