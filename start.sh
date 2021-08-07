#!/bin/bash

START_TIME=$(date +%s)
LIFETIME=86400
END_TIME=$(($START_TIME + $LIFETIME))

echo "Starting broker at : "$START_TIME
echo "Broker will stop at: "$END_TIME
echo "[`date +%Y-%m-%d" "%T.%3N`] start mqtt broker:"

BROKER_PID=0
while (( $(($(date +%s) < $END_TIME)) )); do
  if [ -e /proc/$BROKER_PID ]; then
    # solange der broker läuft alles gut
    sleep 0
  else
    # wenn der Logger nicht läuft (weil abgestürzt oder gerade zum ersten
    # mal gestartet wird) dann neu starten und PID neu ablegen
    echo "[`date +%Y-%m-%d" "%T.%3N`] initial start or restart after crash."
    /usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf & export BROKER_PID=$!
  fi
  sleep 1
done

echo "[`date +%Y-%m-%d" "%T.%3N`] shutting down broker after planned lifetime"
kill $BROKER_PID
sleep 1
exit