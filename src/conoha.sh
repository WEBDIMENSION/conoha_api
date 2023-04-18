#!/usr/bin/env bash

dir_path=$(cd $(dirname $0) && pwd)
source "$dir_path"/.env

# Get token
TOKEN_RESPONSE=$(curl -s -X POST -H "Accept: application/json" \
  -d '{
      "auth": {
        "passwordCredentials": {
              "username": '\"${USER}\"',
              "password": '\"${PASSWORD}\"'
        },
        "tenantId": '\"${TENANT_ID}\"'
     }
   }' \
  https://identity.tyo2.conoha.io/v2.0/tokens)
#echo $TOKEN_RESPONSE
TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r ".access.token.id")
if [ "$TOKEN" = 'null' ]; then
  echo 'Failed. missing USER or PASSWORD or TENANTID.'
  exit
else
  echo 'Success. Getting API Token.'
fi

if [ "$1" = "servers" ]; then
  # Get Serers
  GET_VMS_RESPONSE=$(curl -s -X GET \
    -H "Accept: application/json" \
    -H "X-Auth-Token: ${TOKEN}" \
    https://compute.tyo2.conoha.io/v2/${TENANT_ID}/servers/detail)
    echo "${GET_VMS_RESPONSE}" | jq . > "$dir_path"/json/servers.json
  len=$(echo ${GET_VMS_RESPONSE} | jq ".servers" | jq length)
  for j in $(seq 0 $(($len - 1))); do
    echo $GET_VMS_RESPONSE | jq -r ".servers[$j].metadata.instance_name_tag"
  done

fi
if [ "$1" = "get_info" ] || [ "$1" = "check" ]; then
  # Get flavors
  GET_FLAVORS_RESPONSE=$(curl -s -X GET \
    -H "Accept: application/json" \
    -H "X-Auth-Token: ${TOKEN}" \
    https://compute.tyo2.conoha.io/v2/${TENANT_ID}/flavors)

  # Get images
  GET_IMAGES_RESPONSE=$(curl -s -X GET \
    -H "Accept: application/json" \
    -H "X-Auth-Token: ${TOKEN}" \
    https://image-service.tyo2.conoha.io/v2/images)

  ## Get innformation
  if [ "$1" = "get_info" ]; then
    echo "${GET_FLAVORS_RESPONSE}" | jq . >"$dir_path"/json/flavers.json
    echo "Success: Create flavers.json"
    echo "${GET_IMAGES_RESPONSE}" | jq . >"$dir_path"/json/images.json
    echo "Success: Create images.json"
  fi

  ## check env variable
  if [ "$1" = "check" ]; then
    len=$(echo "${GET_FLAVORS_RESPONSE}" | jq ".flavors" | jq length)
    for i in $(seq 0 $(($len - 1))); do
      if [ $FLAVOR_ID = $(echo "$GET_FLAVORS_RESPONSE" | jq -r ".flavors[$i].id") ]; then
        PLAN_FLAVOR_ID=$(echo "$GET_FLAVORS_RESPONSE" | jq -r ".flavors[$i].id")
        break
      fi
    done
    len=$(echo "${GET_IMAGES_RESPONSE}" | jq ".images" | jq length)
    for i in $(seq 0 $(($len - 1))); do
      if [ $IMAGE_ID = $(echo $GET_IMAGES_RESPONSE | jq -r ".images[$i].id") ]; then
        PLAN_IMAGE_ID=$(echo $GET_IMAGES_RESPONSE | jq -r ".images[$i].id")
        break
      fi
    done

    if [ -z "$PLAN_FLAVOR_ID" ]; then

      echo 'Failed. ' $FLAVOR_ID ' is not Exist'
      echo 'See! flavors.json'
      exit
    else
      echo 'Success. FLAVOR_ID: ' $FLAVOR_ID ' is Exist'
    fi

    if [ -z "$PLAN_IMAGE_ID" ]; then
      echo 'Failed. missing ' "$IMAGE_ID"' or something.'
      exit
    else
      echo 'Success. IMAGE_ID: ' $IMAGE_ID ' is Exist'
    fi
  fi
fi

## Add VM
if [ "$1" = "add_vm" ]; then
  ADD_VM_RESPONSE=$(curl -s -X POST \
    -H "Accept: application/json" \
    -H "X-Auth-Token: ${TOKEN}" \
    -d '{
      "server": {
        "adminPass": '\"${SERVER_ADMIN_PASSWORD}\"',
        "imageRef": '\"${IMAGE_ID}\"',
        "flavorRef": '\"${FLAVOR_ID}\"',
        "metadata": {
          "instance_name_tag": '\"${TAG_NAME}\"'
        },
        "security_groups":[
          {"name": '\"${SG}\"'
        ]
      }
   }' \
    https://compute.tyo2.conoha.io/v2/${TENANT_ID}/servers | jq .)

  echo "${ADD_VM_RESPONSE}" | jq .> "$dir_path"/json/vm.json
  echo "Success: Create vm.json"
#  CREATE_SERVER_ID=$ADD_VM_RESPONSE
  CREATE_SERVER_ID=$(echo "$ADD_VM_RESPONSE" | jq -r ".server.id")
  if [ -z "$CREATE_SERVER_ID" ]; then
    echo 'Failed. missing Create Server.'
    exit
  else
    echo 'Success. Create Server.VM. server id : ' $CREATE_SERVER_ID
  fi
  # Wait for create server
  span=10
  wait=$((CREATE_SERVER_WAIT / span))
  echo "Wait ${CREATE_SERVER_WAIT}s For server create"
  for i in $(seq 0 10 100); do
    COUNT=$i
    STR="${STR}##"
    printf "%-22s(%3d%%)\r" "$STR" "$COUNT"
    sleep $wait
  done
  printf "%20s\r"

  #Get Server IP
  echo "Try get server info server_id : ${CREATE_SERVER_ID}"
  VM_INFO_RESPONSE=$(curl -s -X GET \
    -H "Accept: application/json" \
    -H "X-Auth-Token: ${TOKEN}" \
    https://compute.tyo2.conoha.io/v2/${TENANT_ID}/servers/"${CREATE_SERVER_ID}")
  echo ${VM_INFO_RESPONSE} | jq . > "$dir_path"/json/vm_detail.json
  len=$(echo ${VM_INFO_RESPONSE} | jq '.["server"]["addresses"][]' | jq length)
  for i in $(seq 0 $(($len - 1))); do
    if [ '4' = $(echo $VM_INFO_RESPONSE | jq '.["server"]["addresses"][]' | jq -r ".[$i].version") ]; then
      CREATE_SERVER_IP=$(echo "$VM_INFO_RESPONSE" | jq '.["server"]["addresses"][]' | jq -r ".[$i].addr")
      echo "Create server IP address : ""$CREATE_SERVER_IP"
      break
    fi
  done

  # Ready For Test

  cat <<__END_OF_MESSAGE__ > ${ANSIBLE_HOST_DIR}/${TAG_NAME}
[softether]
root
ansible_user

[add_ansible_user]
root
[add_ansible_user:vars]
ansible_user=root
ansible_host=$CREATE_SERVER_IP
ansible_port=22
ansible_ssh_pass=$SERVER_ADMIN_PASSWORD

[ansible_users]
ansible_user
[ansible_users:vars]
ansible_host=$CREATE_SERVER_IP
ansible_user=ansible-user
ansible_port=$SSH_PORT
ansible_ssh_private_key_file=roles/ansible_user/files/ansible_rsa
__END_OF_MESSAGE__

fi

## Destroy VM
if [ "$1" = "destroy_vm" ]; then
  if [ "$2" = "" ]; then
      echo "Not param TagName"
      exit
  fi
  ###  Get vms
  GET_VMS_RESPONSE=$(curl -s -X GET \
    -H "Accept: application/json" \
    -H "X-Auth-Token: ${TOKEN}" \
    https://compute.tyo2.conoha.io/v2/${TENANT_ID}/servers/detail)
  len=$(echo ${GET_VMS_RESPONSE} | jq ".servers" | jq length)
  for i in $(seq 0 $(($len - 1))); do
    if [ "$2" = $(echo $GET_VMS_RESPONSE | jq -r ".servers[$i].metadata.instance_name_tag") ]; then
      DELETE_VM_ID=$(echo $GET_VMS_RESPONSE | jq -r ".servers[$i].id")
      echo "DELETE_VM_ID : "$DELETE_VM_ID
      break
    fi
  done

  if [ -z $DELETE_VM_ID ]; then
    echo "Failed. Not Found Server tag_name is $2"
    exit
  else
    echo "Success. Found Server tag_name is $2"
  fi

  ### Delete vm
  DELETE_VM_RESPONSE=$(curl -s -X DELETE \
    -H "Accept: application/json" \
    -H "X-Auth-Token: ${TOKEN}" \
    https://compute.tyo2.conoha.io/v2/${TENANT_ID}/servers/${DELETE_VM_ID})
  if [ -z $DELETE_VM_RESPONSE ]; then
    echo "Success. Destroy Server tag_name is $2"
  else
    echo "Failed. Destroy Server tag_name is $2"
    exit
  fi

  rm ${ANSIBLE_HOST_DIR}/${TAG_NAME}
fi

## Get Security group
if [ "$1" = "sg" ]; then
  SG_RESPONSE=$(curl -s -X GET \
    -H "Accept: application/json" \
    -H "X-Auth-Token: ${TOKEN}" \
    https://networking.tyo2.conoha.io/v2.0/security-groups)
  echo $SG_RESPONSE | jq .  > "$dir_path"/json/sg.json
fi
