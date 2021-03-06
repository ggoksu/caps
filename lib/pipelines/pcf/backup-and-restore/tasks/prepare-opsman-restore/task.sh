#!/bin/bash

source ~/scripts/iaas-func.sh
source ~/scripts/opsman-func.sh
iaas::initialize

[[ -n "$TRACE" ]] && set -x
set -e

if [[ -d restore-metadata ]]; then
    source restore-metadata/metadata
elif [[ $backup_mounted == yes ]]; then
    if [[ -e $backup_path/metadata ]]; then
        source $backup_path/metadata
    else
        echo "ERROR! Unable to locate backup metadata."
        exit 1
    fi
else
    echo "ERROR! Unable to locate backup metadata."
    exit 1
fi

# Wait for any current apply jobs to finish

if [[ -n "$OPSMAN_USERNAME" ]]; then
    opsman::login "$OPSMAN_HOST" "$OPSMAN_USERNAME" "$OPSMAN_PASSWORD" "$OPSMAN_DECRYPTION_KEY"
elif [[ -n "$OPSMAN_CLIENT_ID" ]]; then
    opsman::login_client "$OPSMAN_HOST" "$OPSMAN_CLIENT_ID" "$OPSMAN_CLIENT_SECRET" "$OPSMAN_DECRYPTION_KEY"
else
    echo "ERROR! Pivotal Operations Manager credentials were not provided."
    exit 1
fi
opsman::wait_for_last_apply_to_finish
opsman::kill_active_sessions

cat <<EOF > job-session/env
#!/bin/bash

export RESTORE_TIMESTAMP=$RESTORE_TIMESTAMP
if [[ -z "\$RESTORE_TIMESTAMP" ]]; then
    echo "ERROR! Restore timestamp is empty."
    exit 1
fi

source ~/scripts/opsman-func.sh

opsman_url='$opsman_url'
opsman_token='$opsman_token'

export BOSH_HOST=''\$(opsman::get_director_ip)''
if [[ -z "\$BOSH_HOST" ]]; then
    echo "ERROR! Unable to retrieve BOSH host address. You may need to re-run prepare task to refresh the ops manager token."
    exit 1
fi

export CA_CERT='$(opsman::download_bosh_ca_cert)'
export BBR_SSH_KEY=''\$(opsman::get_bbr_ssh_key)''

function bosh_user_creds() { 
    export BOSH_USER=''\$(opsman::get_director_user)''
    export BOSH_PASSWD=''\$(opsman::get_director_password)''
}

function bosh_vm_creds() { 
    export BOSH_VM_USER=''\$(opsman::get_director_vm_user)''
    export BOSH_VM_PASSWD=''\$(opsman::get_director_vm_password)''
}

function bosh_client_creds() { 
    export BOSH_CLIENT='ops_manager'
    export BOSH_CLIENT_SECRET=''\$(opsman::get_director_client_secret ops_manager)''
}

function bosh_vm_vcap_password() { 
    opsman::get_product_vm_credential "\$1" "\$2"
}

function mysql_creds() { 
    export ERT_MYSQL_USER=''\$(opsman::get_product_credential cf- mysql_admin_credentials | jq -r .credential.value.identity)''
    export ERT_MYSQL_PASSWORD=''\$(opsman::get_product_credential cf- mysql_admin_credentials | jq -r .credential.value.password)''
    export MYSQL_USER=''\$(opsman::get_product_credential p-mysql- mysql_admin_password | jq -r .credential.value.identity)''
    export MYSQL_PASSWORD=''\$(opsman::get_product_credential p-mysql- mysql_admin_password | jq -r .credential.value.password)''
}

function rmq_creds() { 
    export RMQ_ADMIN_USER=''\$(opsman::get_product_credential p-rabbitmq- server_admin_credentials | jq -r .credential.value.identity)''
    export RMQ_ADMIN_PASSWORD=''\$(opsman::get_product_credential p-rabbitmq- server_admin_credentials | jq -r .credential.value.password)''
}
EOF

set +e +x
