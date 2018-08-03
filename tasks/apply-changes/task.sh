#!/bin/bash

set -x

if [[ $DEBUG == true ]]; then
  set -ex
else
  set -e
fi

# Need uaac-cli on container or install it
#Requires curl

chmod +x om-cli/om-linux

CMD=./om-cli/om-linux
USE_OM_FOR_SINGLE_DEPLOYMENT=false


OLD_OM_DEPLOY (){

   $CMD -t https://$OPS_MGR_HOST -k -u $OPS_MGR_USR -p $OPS_MGR_PWD apply-changes  --ignore-warnings true

}

SINGLE_DEPLOYMENT(){

  uaac target https://$OPS_MGR_HOST/uaa --skip-ssl-validation
  #login using admin credentials
  uaac token owner get opsman -s "" $OPS_MGR_USR -p $OPS_MGR_PWD
  #get token
  TOKEN=$(uaac context | grep access_token | cut -d':' -f2 | cut -d' ' -f2)

  #USE om to find the guid of the product to apply changes.
  #May need a param passed in to help identify
  #PRODUCT_GUID   #find guid

  #Applying changes to the director and products specified in `deploy_products` array
  echo
  curl "https://$OPS_MGR_HOST/api/v0/installations" -k \
      -X POST \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{ "deploy_products": $1,"ignore_warnings": true }'

  echo "Executed command"

}

#Get om version
OM_VERSION=$($CMD -t ${OPS_MGR_HOST} -u ${OPS_MGR_USR} -p ${OPS_MGR_PWD} -k staged-products | grep p-bosh | cut -d'|' -f3)
OM_VERSION=${OM_VERSION:1:3}
echo "OM version is ${OM_VERSION}"
if [[ "${OM_VERSION}" == "2.2" || "${OM_VERSION}" == "2.3" || "${OM_VERSION}" == "2.4" ]]; then
  USE_OM_FOR_SINGLE_DEPLOYMENT=true
else
  USE_OM_FOR_SINGLE_DEPLOYMENT=false
fi
#Check if OM Version is 2.2+

if [[ ${USE_OM_FOR_SINGLE_DEPLOYMENT} ]]; then
  #check all the pending installs
  # currently not checking for delete or other states, just install
  PRODUCTS=$($CMD -t opsman.gcp.sandyg.org -u admin -p Piv0tal! -k pending-changes | grep install | cut -d'|' -f2)
  #echo ${PRODUCTS}
  myarr=( $PRODUCTS )
  SIZE=${#myarr[@]}
  echo $SIZE
  if [[ $SIZE > 1 ]]; then
    #echo "size is >1"
    DEPLOY_ARRAY="["
    for i in "${myarr[@]}"
    do
        DEPLOY_ARRAY=${DEPLOY_ARRAY}\"${i}\",
    done
    DEPLOY_ARRAY=${DEPLOY_ARRAY%,}
    DEPLOY_ARRAY=${DEPLOY_ARRAY}]

    echo $DEPLOY_ARRAY
    SINGLE_DEPLOYMENT "$DEPLOY_ARRAY"
  elif [[ $SIZE == 0 ]]
  then
    ###Can this happen???? If this does we should use old OM deploy
    echo "size is 0, something fishy"
    OLD_OM_DEPLOY
  else
    #echo "size is one"
    DEPLOY_ARRAY=[\"$PRODUCTS\"]
    SINGLE_DEPLOYMENT "$DEPLOY_ARRAY"
  fi

else
  OLD_OM_DEPLOY
fi
