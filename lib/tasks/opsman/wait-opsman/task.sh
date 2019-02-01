#!/bin/bash

source ~/scripts/iaas-func.sh
source ~/scripts/opsman-func.sh
iaas::initialize

[[ -n "$TRACE" ]] && set -x
set +e -o pipefail

[[ "$(opsman::check_available "https://$OPSMAN_HOST")" == "available" ]] || exit 0

start_time=$(date +%s)
while [[ true ]]; do

  installations_resp=$(om --skip-ssl-validation \
    --target "https://${OPSMAN_HOST}" \
    --client-id "${OPSMAN_CLIENT_ID}" \
    --client-secret "${OPSMAN_CLIENT_SECRET}" \
    --username "${OPSMAN_USERNAME}" \
    --password "${OPSMAN_PASSWORD}" \
    curl --silent --path /api/v0/installations)

  if [[ $? -ne 0 ]]; then
    echo -e "$installations_resp\n"
    echo -e "ERROR! Could not login to ops man."
    exit 1
  fi

  echo "$installations_resp" | jq -e -r '.installations[0] | select(.status=="running")' >/dev/null
  if [[ $? -ne 0 ]]; then
      echo "No running installs in progress detected. Proceeding"
      break
  fi

  sleep 10
  time_now=$(date +%s)

  ss=$(($time_now-$start_time))
  h=$(($ss/3600))
  m=$(($ss/60-$h*60))
  s=$(($ss-$m*60-$h*3600))
  time_elapsed=$(printf "%02d" $h):$(printf "%02d" $m):$(printf "%02d" $s)

  echo -e -n "Waiting $time_elapsed hours for running installs to complete.\r"
done
