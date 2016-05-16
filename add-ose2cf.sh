#!/bin/bash


function usage {
  echo "$0: add a openshift provider to cloud forms"
  echo "$0: (run from an ose master)"
  echo "========================================================"
  echo "  usage:"
  echo "  "$0 "-h <CloudForms Host Name> -u <CloudForms User> -p <CloudForms Password> -n <Provider Name> -c <Provider Host Name>"
        exit 0
}

while getopts ":h:u:p:n:c:" option
do
  case "$option" in
    h) cf_host=$OPTARG;;
    u) cf_user=$OPTARG;;
    p) cf_pw=$OPTARG;;
    n) provider_name=$OPTARG;;
    c) provider_host=$OPTARG;;
    h) usage
  esac
done

if [[ -z "$cf_host" ]] || [[ -z "$cf_user" ]] || [[ -z "$cf_pw" ]] || [[ -z "$provider_name" ]] || [[ -z $provider_host ]]; then
        usage
        exit 0
fi

auth_key=$(oc get -n management-infra secrets $(oc get -n management-infra sa/management-admin --template='{{range .secrets}}{{printf "%s\n" .name}}{{end}}' | head -1) --template='{{.data.token}}' | base64 -d)

add_provider=$(curl -s -k -XPOST -d@- https://$cf_host/api/providers/ -u $cf_user:$cf_pw <<EOF
{
  "name":"$provider_name",
  "port":"8443",
  "hostname":"$provider_host",
  "zone_id":1,
  "type":"ManageIQ::Providers::Openshift::ContainerManager",
  "tenant_id":1,
  "credentials": [{
    "auth_type": "bearer",
    "userid": "admin",
    "auth_key": "$auth_key"
    }]
}
EOF
)

[[ "$add_provider" =~ "Host Name has already been taken" ]] && echo "provider already exists, exiting" && exit 1
[[ "$add_provider" =~ "error" ]] && echo "failed to add provider! please investigate, exiting" && exit 1
[[ "$add_provider" =~ "created_on" ]] && echo "successfully added $provider_name to $cf_host" && exit 0

