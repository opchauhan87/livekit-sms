#!/bin/bash

#################################################
# CONFIG
#################################################

URL="ws://10.120.10.50:7880"
API_KEY="devkey"
API_SECRET="2bd13b4c3b7d4422be92cf244be9f379"

ROOM_COUNT=${1:-20}
DURATION=${2:-10m}

PARTICIPANTS_PER_ROOM=2

CPU_LIMIT=80
INTERVAL=10

LOGFILE="benchmark_$(date +%F_%H%M).log"

#################################################
# CLEANUP
#################################################

cleanup() {

echo ""
echo "Stopping monitor..."

kill "$MON_PID" 2>/dev/null

pkill -f "lk load-test" 2>/dev/null

echo ""
echo "Benchmark completed"
echo "Logs saved -> $LOGFILE"

}

trap cleanup EXIT

#################################################
# MONITOR
#################################################

monitor() {

while true
do

clear

TIME=$(date)

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')

MEM=$(free -m | awk '/Mem:/ {print $3"/"$2" MB"}')

CONN=$(ss -ant | wc -l)

echo ""
echo "=============================================================="

printf "%-25s %-20s\n" "Time" "$TIME"
printf "%-25s %-20s\n" "CPU Usage" "${CPU}%"
printf "%-25s %-20s\n" "Memory" "$MEM"
printf "%-25s %-20s\n" "Connections" "$CONN"
printf "%-25s %-20s\n" "Rooms Running" "$ROOM_COUNT"

echo "=============================================================="

docker stats \
--no-stream \
--format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

echo "$TIME CPU=$CPU MEM=$MEM CONN=$CONN" \
>> "$LOGFILE"

if [ "$CPU" -gt "$CPU_LIMIT" ]
then
 echo ""
 echo "CPU threshold exceeded"

 pkill -f "lk load-test"

 exit 1
fi

sleep "$INTERVAL"

done

}

#################################################
# START
#################################################

echo ""
echo "================================================"
echo "Rooms            : $ROOM_COUNT"
echo "Participants/Rm  : $PARTICIPANTS_PER_ROOM"
echo "Total Users       : $((ROOM_COUNT * PARTICIPANTS_PER_ROOM))"
echo "Duration         : $DURATION"
echo "================================================"

monitor &
MON_PID=$!

sleep 5

echo ""
echo "Starting benchmark..."

for i in $(seq 1 $ROOM_COUNT)
do

ROOM="benchmark-room-$RANDOM-$i"

lk load-test \
  --url "$URL" \
  --api-key "$API_KEY" \
  --api-secret "$API_SECRET" \
  --room "$ROOM" \
  --audio-publishers 1 \
  --subscribers 1 \
  --duration "$DURATION" &

done

wait

echo ""
echo "Benchmark finished"
