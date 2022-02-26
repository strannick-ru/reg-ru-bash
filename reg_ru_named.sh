#!/usr/bin/env bash

#
# deploy a DNS challenge on reg.ru
#

set -e
set -u
set -o pipefail

function deploy_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
    local SUBDOMAIN="_acme-challenge"
    local NSUPDATE="nsupdate -k /etc/bind/key/dnsupdater.key" TTL=30

    D_LEN=$( echo "$DOMAIN" | sed 's/\./\n/g' | wc -l )

    echo "deploy_challenge called: ${DOMAIN}, ${SUBDOMAIN}, ${TOKEN_VALUE}, $D_LEN"

    ### check for domain name correct and exist

    if (( $D_LEN < 2 )); then echo "Wrong domain. Exit"; exit; fi
    if (( $D_LEN >= 2 ))
    then
      DOM=()
      for ((i=1; i <= "$D_LEN"; i++))
        do
          DOM[$i]=$( echo "$DOMAIN" | cut -d'.' -f"$i" )
        done

      let "DOM2 = $D_LEN - 1"
      DOMAIN1=$( echo "${DOM[$DOM2]}.${DOM[$D_LEN]}" )
    else
      DOMAIN1="${1}"
    fi

    # add CNAME for _acme-challenge
    SUBDOMAIN1=$( echo "${DOMAIN}" | sed "s/^\*\.//g" | sed "s/${DOMAIN1}//g" )

    curl -X POST "$REGRU_url/add_cname" --data "username=$REGRU_user&password=$REGRU_pass&output_content_type=plain&show_input_params=0&domain_name=$DOMAIN1&input_format=json&input_data={\"domains\":[{\"dname\":\"$DOMAIN1\"}],\"subdomain\":\"$SUBDOMAIN.$SUBDOMAIN1$DOMAIN1.\",\"canonical_name\":\"$NS_zone\"}" > /dev/null 2>&1

    # use force of local bind9, Luke!
    printf "server %s\nupdate add %s. %d in TXT \"%s\"\nsend\n" "${NS_server}" "${NS_zone}" "${TTL}" "${TOKEN_VALUE}" | $NSUPDATE

    if [ "${SUBDOMAIN1}" != "" ]
    then
        SUBDOMAIN1=""
        curl -X POST "$REGRU_url/add_cname" --data "username=$REGRU_user&password=$REGRU_pass&output_content_type=plain&show_input_params=0&domain_name=$DOMAIN1&input_format=json&input_data={\"domains\":[{\"dname\":\"$DOMAIN1\"}],\"subdomain\":\"$SUBDOMAIN.$SUBDOMAIN1$DOMAIN1.\",\"canonical_name\":\"$NS_zone\"}" > /dev/null 2>&1
        printf "server %s\nupdate add %s. %d in TXT \"%s\"\nsend\n" "${NS_server}" "${NS_zone}" "${TTL}" "${TOKEN_VALUE}" | $NSUPDATE
    fi

    secs=$((1 * 60))
    while [ $secs -gt 0 ]; do
       echo -ne "$secs\033[0K\r"
       sleep 1
       : $((secs--))
    done
}

function clean_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
    local SUBDOMAIN="_acme-challenge"
    local NSUPDATE="nsupdate -k /etc/bind/key/dnsupdater.key" TTL=30

    D_LEN=$( echo "$DOMAIN" | sed 's/\./\n/g' | wc -l )

    echo "clean_challenge called: ${DOMAIN}, ${SUBDOMAIN}, ${TOKEN_VALUE}, $D_LEN"

    ### check for domain name correct and exist

    if (( $D_LEN < 2 )); then echo "Wrong domain. Exit"; exit; fi
    if (( $D_LEN > 2 ))
    then
      DOM=()
      for ((i=1; i <= "$D_LEN"; i++))
        do
          DOM[$i]=$( echo "$DOMAIN" | cut -d'.' -f"$i" )
        done

      let "DOM2 = $D_LEN - 1"
      DOMAIN1=$( echo "${DOM[$DOM2]}.${DOM[$D_LEN]}" )
    else
      DOMAIN1="${1}"
    fi

    RR=$( curl --silent -X POST "$REGRU_url/get_resource_records" --data "username=$REGRU_user&password=$REGRU_pass&output_content_type=plain&show_input_params=0&domain_name=$DOMAIN1&input_format=json&input_data={\"domains\":[{\"dname\":\"$DOMAIN1\"}]}" )

    ### Clean up all _acme-challenge records
    for i in $( echo "${RR}" | grep "$SUBDOMAIN" | grep "subname" | cut -d'"' -f4 )
      do
        RECTYPE=$( echo "${RR}" | grep -B2 "${i}\"" | grep "rectype" | cut -d'"' -f4 )
        SUBNAME=$( echo "${RR}" | grep "${i}\"" | cut -d'"' -f4 )
        curl -X POST "$REGRU_url/remove_record" --data "username=$REGRU_user&password=$REGRU_pass&output_content_type=plain&show_input_params=0&domain_name=$DOMAIN1&input_format=json&input_data={\"domains\":[{\"dname\":\"$DOMAIN1\"}],\"subdomain\":\"$SUBNAME\",\"record_type\":\"$RECTYPE\"}" > /dev/null 2>&1
      done

    printf "server %s\nupdate delete %s %d TXT\nsend\n" "${NS_server}" "${NS_zone}" "${TTL}" | $NSUPDATE
}

function invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"

    echo "invalid_challenge called: ${DOMAIN}, ${RESPONSE}"
}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    echo "deploy_cert called: ${DOMAIN}, ${KEYFILE}, ${CERTFILE}, ${FULLCHAINFILE}, ${CHAINFILE}"
}

function unchanged_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    echo "unchanged_cert called: ${DOMAIN}, ${KEYFILE}, ${CERTFILE}, ${FULLCHAINFILE}, ${CHAINFILE}"
}

exit_hook() {
  :
}

startup_hook() {
  :
}

HANDLER=$1; shift;
if [ -n "$(type -t $HANDLER)" ] && [ "$(type -t $HANDLER)" = function ]; then
  $HANDLER "$@"
fi
