#!/bin/sh

#################################################
# AnripDdns v5.08
# Dynamic DNS using DNSPod API
# Original by anrip<mail@anrip.com>, http://www.anrip.com/ddnspod
# Edited by ProfFan
#################################################

arIpAddress() {
  local extip
  extip=$(ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address')
  if [ "x${extip}" = "x" ]; then
    echo 'failed to get wan ip' >&2
    return 1
  fi
  echo $extip
  return 0
}

#DIR=$(dirname "$(readlink -f "$0")")
DIR=/etc/ddns

# Global Variables:

# Token-based Authentication
arToken=""
# Account-based Authentication
arMail=""
arPass=""

# Load config

#. $DIR/dns.conf

# Get Domain IP
# arg: domain
arDdnsInfo() {
  local domainID recordID recordIP
  # Get domain ID
  domainID=$(arApiPost "Domain.Info" "domain=${1}")
  domainID=$(echo $domainID | jsonfilter -e '@.domain.id')

  # Get Record ID
  recordID=$(arApiPost "Record.List" "domain_id=${domainID}&sub_domain=${2}")
  recordID=$(echo $recordID | jsonfilter -e '@.records[0].id')

  # Last IP
  recordIP=$(arApiPost "Record.Info" "domain_id=${domainID}&record_id=${recordID}")
  recordIP=$(echo $recordIP | jsonfilter -e '@.record.value')

  # Output IP
  case "$recordIP" in 
    [1-9][0-9]*)
      echo $recordIP
      return 0
      ;;
    *)
      echo "Get Record Info Failed!"
      return 1
      ;;
  esac
}

# Get data
# arg: type data
arApiPost() {
  local inter="https://dnsapi.cn/${1:?'Info.Version'}"
  if [ "x${arToken}" = "x" ]; then # undefine token
    local param="login_email=${arMail}&login_password=${arPass}&format=json&${2}"
  else
    local param="login_token=${arToken}&format=json&${2}"
  fi
  curl -s -k -X POST $inter -d $param
}

# Update
# arg: main domain  sub domain
arDdnsUpdate() {
  local domainID recordID recordRS recordCD recordIP myIP
  # Get domain ID
  domainID=$(arApiPost "Domain.Info" "domain=${1}")
  domainID=$(echo $domainID | sed 's/.*{"id":"\([0-9]*\)".*/\1/')

  # Get Record ID
  recordID=$(arApiPost "Record.List" "domain_id=${domainID}&sub_domain=${2}")
  recordID=$(echo $recordID | sed 's/.*\[{"id":"\([0-9]*\)".*/\1/')

  # Update IP
  myIP=$(arIpAddress)
  if [ ! $? -eq 0 ]; then
    return 1
  fi
  recordRS=$(arApiPost "Record.Ddns" "domain_id=${domainID}&record_id=${recordID}&sub_domain=${2}&record_type=A&value=${myIP}&record_line=%e9%bb%98%e8%ae%a4")
  recordCD=$(echo $recordRS | sed 's/.*{"code":"\([0-9]*\)".*/\1/')
  recordIP=$(echo $recordRS | sed 's/.*,"value":"\([0-9\.]*\)".*/\1/')

  # Output IP
  if [ "$recordIP" = "$myIP" ]; then
    if [ "$recordCD" = "1" ]; then
      echo $recordIP
      return 0
    fi
    # Echo error message
    echo $recordRS | sed 's/.*,"message":"\([^"]*\)".*/\1/'
    return 1
  else
    echo "Update Failed! Please check your network."
    return 1
  fi
}

# DDNS Check
# Arg: Main Sub
arDdnsCheck() {
  local postRS
  local lastIP
  local hostIP=$(arIpAddress)
  if [ ! $? -eq 0 ]; then
    return 1
  fi
  echo "Updating Domain: ${2}.${1}"
  echo "hostIP: ${hostIP}"
  lastIP=$(arDdnsInfo $1 $2)
  if [ $? -eq 0 ]; then
    echo "lastIP: ${lastIP}"
    if [ "$lastIP" != "$hostIP" ]; then
      postRS=$(arDdnsUpdate $1 $2)
      if [ $? -eq 0 ]; then
        echo "postRS: ${postRS}"
        return 0
      else
        echo ${postRS}
        return 1
      fi
    fi
    echo "Last IP is the same as current IP!"
    return 0
  fi
  echo ${lastIP}
  return 1
}

# DDNS
#echo ${#domains[@]}
#for index in ${!domains[@]}; do
#    echo "${domains[index]} ${subdomains[index]}"
#    arDdnsCheck "${domains[index]}" "${subdomains[index]}"
#done

. $DIR/dns.conf
