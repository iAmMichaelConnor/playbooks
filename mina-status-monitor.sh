#Credit to _thanos for the original snarkstopper - https://forums.minaprotocol.com/t/guide-script-automagically-stops-snark-work-prior-of-getting-a-block-proposal/299

#Credit also to jrwashburn: https://github.com/jrwashburn/mina-node-install/blob/main/scripts/mina-status-monitor.sh

MINA_STATUS=""
STAT=""
CONNECTINGCOUNT=0
OFFLINECOUNT=0
TOTALCONNECTINGCOUNT=0
TOTALOFFLINECOUNT=0
TOTALSTUCK=0
readonly SECONDS_PER_MINUTE=60
readonly SECONDS_PER_HOUR=3600
CATCHUPSTARTTIME=0
TIMESINCECATCHUPSTART=0
TIMESINCECATCHUPSTARTSEC=0
TIMESINCECATCHUPSTARTMIN=0

while :; do
  # MINA_STATUS="$(mina client status -json)"
  MINA_STATUS="$(mina client status -json | sed "1 d")"
  #MINA_STATUS="$(docker exec -ti mina mina client status -json | sed "1 d")" # the `sed "1 d"` removes the first line of output, which in the docker case says "Using password from environment variable CODA_PRIVKEY_PASS", which confuses jq

  STAT="$(echo $MINA_STATUS | jq .sync_status)"
  NEXTPROP="$(echo $MINA_STATUS | jq .next_block_production.timing[1].time)"
  HIGHESTBLOCK="$(echo $MINA_STATUS | jq .highest_block_length_received)"
  HIGHESTUNVALIDATEDBLOCK="$(echo $MINA_STATUS | jq .highest_unvalidated_block_length_received)"

  NOW="$(date +%s%N | cut -b1-13)"

  # Calculate difference between validated and unvalidated blocks
  # If block height is more than 10 block behind, somthing is likely wrong
  DELTAVALIDATED="$(($HIGHESTUNVALIDATEDBLOCK-$HIGHESTBLOCK))"
  echo "DELTA VALIDATE: ", $DELTAVALIDATED
  if [[ "$DELTAVALIDATED" -gt 5 ]]; then
    echo "Node stuck validated block height delta more than 5 blocks"
    ((TOTALSTUCK++))
    systemctl --user restart mina
    #docker stop mina

    CATCHUPSTARTTIME=0
    TIMESINCECATCHUPSTART=0
    TIMESINCECATCHUPSTARTSEC=0
    TIMESINCECATCHUPSTARTMIN=0
  fi

  if [[ "$STAT" == "\"Synced\"" ]]; then
    OFFLINECOUNT=0
    CONNECTINGCOUNT=0

    CATCHUPSTARTTIME=0
    TIMESINCECATCHUPSTART=0
    TIMESINCECATCHUPSTARTSEC=0
    TIMESINCECATCHUPSTARTMIN=0
  fi

  # If weve been stuck in catchup for ages, restart, because somethings wrong
  if [[ "$STAT" == "\"Catchup\"" ]]; then
    if [[ "$CATCHUPSTARTTIME" -eq 0 ]]; then
      CATCHUPSTARTTIME="$NOW"
    else
      TIMESINCECATCHUPSTART="$(($NOW - $CATCHUPSTARTTIME))"
      TIMESINCECATCHUPSTARTSEC="${TIMESINCECATCHUPSTART:0:-3}"
      TIMESINCECATCHUPSTARTMIN="$((${TIMESINCECATCHUPSTARTSEC} / ${SECONDS_PER_MINUTE}))"

      echo "Been in catchup for this many minutes:", $TIMESINCECATCHUPSTARTMIN
      if [[ "$TIMESINCECATCHUPSTARTMIN" -gt 30 ]]; then
        echo "Been in catchup too long... restarting..."
        systemctl --user restart mina
        #docker stop mina

        CATCHUPSTARTTIME=0
        TIMESINCECATCHUPSTART=0
        TIMESINCECATCHUPSTARTSEC=0
        TIMESINCECATCHUPSTARTMIN=0
      fi
    fi
  fi

  if [[ "$STAT" == "\"Connecting\"" ]]; then
    ((CONNECTINGCOUNT++))
    ((TOTALCONNECTINGCOUNT++))
  fi

  if [[ "$STAT" == "\"Offline\"" ]]; then
    ((OFFLINECOUNT++))
    ((TOTALOFFLINECOUNT++))
  fi

  if [[ "$CONNECTINGCOUNT" -gt 1 ]]; then
    systemctl --user restart mina
    #docker stop mina

    CONNECTINGCOUNT=0

    CATCHUPSTARTTIME=0
    TIMESINCECATCHUPSTART=0
    TIMESINCECATCHUPSTARTSEC=0
    TIMESINCECATCHUPSTARTMIN=0
  fi

  if [[ "$OFFLINECOUNT" -gt 3 ]]; then
    systemctl --user restart mina
    #docker stop mina

    OFFLINECOUNT=0

    CATCHUPSTARTTIME=0
    TIMESINCECATCHUPSTART=0
    TIMESINCECATCHUPSTARTSEC=0
    TIMESINCECATCHUPSTARTMIN=0
  fi

  echo "Status:" $STAT, "Connecting Count, Total:" $CONNECTINGCOUNT $TOTALCONNECTINGCOUNT, "Offline Count, Total:" $OFFLINECOUNT $TOTALOFFLINECOUNT, "Node Stuck Below Tip:" $TOTALSTUCK
  sleep 300s
  #check if sleep exited with break (ctrl+c) to exit the loop
  test $? -gt 128 && break;
done
