#!/bin/bash
set -x
function  is_true()
{
    for arg
    do
        [[ x$arg =~ x(1|true) ]] || return 0
    done

    return 1
}


function is_false()
{
    for arg
    do
        [[ x$arg =~ x(0|false) ]] || return 0
    done

    return 1
}

function wait_cloud_init()
{
  # exit early if cloud-init log does not exist (e.g. cloud-init not installed)
  [ -f /var/log/cloud-init.log ] || return 0
  systemctl is-enabled cloud-init.service || return 0
  while :; do
    systemctl show cloud-init |grep -q SubState=exited && break
    tail -n5 /var/log/cloud-init.log | grep -q 'Cloud-init .* finished' && break
    sleep 1
  done
}

function yum_install_or_exit()
{
    echo "Openshift V3: yum install $*"
    Count=0
    while true
    do
        yum install -y $*
        if [ $? -eq 0 ]; then
            return
        elif [ $Count -gt 3 ]; then
            echo "Openshift V3: Command fail: yum install $*"
            echo "Openshift V3: Please ensure relevant repos are configured"
            exit 1
        fi
        let Count+=1
    done
}

function install_named_pkg()
{
    yum_install_or_exit bind 
}

function configure_bind()
{
    rndc-confgen -a -r /dev/urandom
    restorecon /etc/rndc.* /etc/named.*
    chown root:named /etc/rndc.key
    chmod 640 /etc/rndc.key

    # Set up DNS forwarding if so directed.
    echo "forwarders { ${nameservers} } ;" > /var/named/forwarders.conf
    restorecon /var/named/forwarders.conf
    chmod 644 /var/named/forwarders.conf

    # Install the configuration file for the OpenShift Enterprise domain
    # name.
    rm -rf /var/named/dynamic
    mkdir -p /var/named/dynamic

    chgrp named -R /var/named
    chown named -R /var/named/dynamic
    restorecon -rv /var/named

    # Replace named.conf.
    cat <<EOF > /etc/named.conf
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//

options {
  listen-on port 53 { any; };
  directory     "/var/named";
  dump-file     "/var/named/data/cache_dump.db";
  statistics-file "/var/named/data/named_stats.txt";
  memstatistics-file "/var/named/data/named_mem_stats.txt";
  allow-query     { any; };
  allow-transfer  { "none"; }; # default to no zone transfers

  /* Path to ISC DLV key */
  bindkeys-file "/etc/named.iscdlv.key";

  forward only;
  include "forwarders.conf";
  recursion yes;
  };

logging {
  channel default_debug {
    file "data/named.run";
    severity dynamic;
  };
};

// use the default rndc key
include "/etc/rndc.key";

controls {
  inet 127.0.0.1 port 953
  allow { 127.0.0.1; } keys { "rndc-key"; };
};

include "/etc/named.rfc1912.zones";
EOF


    chown root:named /etc/named.conf
    chcon system_u:object_r:named_conf_t:s0 -v /etc/named.conf

    # actually set up the domain zone(s)
    # bind_key is used if set, created if not. both domains use same key.
    if ! $USE_OPENSTACK_DNS; then
        configure_named_zone ${CONF_HOST_DOMAIN}
        add_infra_records
    fi
    configure_named_zone ${CONF_APP_DOMAIN}
    add_route_records

    chkconfig named on

  # Start named so we can perform some updates immediately.
    service named restart
}


function configure_named_zone()
{
    zone="$1"

    if [ "x$bind_key" = x ]; then
        # Generate a new secret key
        zone_tolower="${zone,,}"
        rm -f /var/named/K${zone_tolower}*
        dnssec-keygen -a HMAC-SHA256 -b 256 -n USER -r /dev/urandom -K /var/named ${zone}
        # $zone may have uppercase letters in it.  However the file that
        # dnssec-keygen creates will have the zone in lowercase.
        bind_key="$(grep Key: /var/named/K${zone_tolower}*.private | cut -d ' ' -f 2)"
        rm -f /var/named/K${zone_tolower}*
    fi

    # Install the key where BIND and oo-register-dns expect it.
    cat <<EOF > /var/named/${zone}.key
key ${zone} {
  algorithm "HMAC-SHA256";
  secret "${bind_key}";
};
EOF

    # Create the initial BIND database.
    cat <<EOF > /var/named/dynamic/${zone}.db
\$ORIGIN .
\$TTL 1    ; 1 seconds (for testing only)
${zone}        IN SOA    ns1.$zone. hostmaster.$zone. (
  2011112904 ; serial
  60         ; refresh (1 minute)
  15         ; retry (15 seconds)
  1800       ; expire (30 minutes)
  10         ; minimum (10 seconds)
  )
  IN NS    $named_hostname.
  IN MX    10 mail.$zone.
\$ORIGIN ${zone}.
ns1                   IN A       ${CONF_DNS_IP}
EOF

    if ! grep ${zone} /etc/named.conf >/dev/null; then
        # Add a record for the zone to named conf
        cat <<EOF >> /etc/named.conf
include "${zone}.key";
zone "${zone}" IN {
  type master;
  file "dynamic/${zone}.db";
  allow-update { key ${zone} ; } ;
};
EOF
    fi
    sed -i "/lo -j ACCEPT/a -A INPUT -m state --state NEW -m udp -p udp --dport 53 -j ACCEPT" /etc/sysconfig/iptables
    sed -i "/lo -j ACCEPT/a -A INPUT -m state --state NEW -m tcp -p tcp --dport 53 -j ACCEPT" /etc/sysconfig/iptables
}

function configure_dns_resolution()
{
    sed -i -e "/search/ d; 1i# The named we install for our OpenShift PaaS must appear first.\\nsearch ${CONF_HOST_DOMAIN}.\\nnameserver ${CONF_DNS_IP}\\n" /etc/resolv.conf

    cat <<EOF > /etc/dhcp/dhclient-$interface.conf
prepend domain-name-servers ${CONF_DNS_IP};
prepend domain-search "${CONF_HOST_DOMAIN}";
EOF
    systemctl restart network.service
}

function add_infra_records()
{
    for host in ${CONF_HOST_LIST//,/ }; do
        key=$(echo $host|awk -F":" '{print $1}')
        value=$(echo $host|awk -F":" '{print $2}')
        if [[ "$value" == *[A-Za-z]* ]]; then
          REC_TYPE=CNAME
          value+=.
        else
          REC_TYPE=A
        fi

        echo "${key}                    IN $REC_TYPE    ${value}" >>/var/named/dynamic/${CONF_HOST_DOMAIN}.db
     done
}

function add_route_records()
{
    multinode=${CONF_IP_LIST//[^,]}
    for host in ${CONF_IP_LIST//,/ }; do
        key=$(echo $host|awk -F":" '{print $1}')
        value=$(echo $host|awk -F":" '{print $2}')
        if [[ "$value" == *[A-Za-z]* ]]; then
            REC_TYPE=CNAME
            value+=.
        else
            REC_TYPE=A
        fi
        # routers will run on masters or nodes, point DNS at them
        if [ "$key" == "$CONF_ROUTER_NODE_TYPE" ] ||
                [ x"$multinode" == x"" ]; then
            echo "*                    IN $REC_TYPE    ${value}" >>/var/named/dynamic/${CONF_APP_DOMAIN}.db
        fi
    done
}

function configure_repos()
{
    cat <<EOF >/etc/yum.repos.d/rhel-jenkins.repo
[rhel-7]
name=RHEL-7
baseurl=${CONF_RHEL_BASE_REPO}/os/
enabled=1
gpgcheck=0

[rhel-7-extra]
name=RHEL-7-extra
baseurl=${CONF_RHEL_BASE_REPO}/extras/os/
enabled=1
gpgcheck=0

[rhel-7-highavailability]
name=RHEL-7-highavailability
baseurl=${CONF_RHEL_BASE_REPO}/highavailability/os/
enabled=1
gpgcheck=0
EOF
}

function clean_repos()
{
    rm -rf /etc/yum.repos.d/*
    subscription-manager unregister
}


function create_router_registry()
{
    oadm registry --credentials=$CONF_CRT_PATH/master/openshift-registry.kubeconfig --images="$CONF_IMAGE_PRE"
    #CA=$CONF_CRT_PATH/master
    #oadm ca create-server-cert --signer-cert=$CA/ca.crt --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt  --hostnames="*.${CONF_APP_DOMAIN}" --cert=cloudapps.crt --key=cloudapps.key
    #cat cloudapps.crt cloudapps.key $CA/ca.crt > cloudapps.router.pem
    #oc get scc privileged -o yaml >privileged.yaml
    #grep "system:serviceaccount:default:default" privileged.yaml || echo "- system:serviceaccount:default:default" >> privileged.yaml
    #oc replace -f privileged.yaml 
    #tmpStr=${CONF_HOST_LIST//[^,]}
    #if [ x"$tmpStr" == x"" ]; then
    #    nodeNum=1
    #else
    #    nodeNum=${#tmpStr}
    #fi
    #oadm router --default-cert=cloudapps.router.pem --credentials=$CONF_CRT_PATH/master/openshift-router.kubeconfig --images="$CONF_IMAGE_PRE" --replicas=$nodeNum --service-account=default
}


function configure_hosts()
{
    for host in ${CONF_HOST_LIST//,/ }; do
        tmpKey=$(echo $host|awk -F":" '{print $1}')
        tmpIp=$(echo $host|awk -F":" '{print $2}')
          grep $tmpip /etc/hosts || echo -e \"$tmpip\t$tmpkey.$DOMAIN_NAME\" >>/etc/hosts
    done
}

function configure_shared_dns()
{
    if ! $USE_OPENSTACK_DNS; then
        configure_named_zone ${CONF_HOST_DOMAIN}
        add_infra_records
    fi
    configure_named_zone ${CONF_APP_DOMAIN}
    add_route_records
    service named restart
}
    
function add_skydns_hosts()
{
    for host in ${CONF_HOST_LIST//,/ }; do
        key=$(echo $host|awk -F":" '{print $1}')
        value=$(echo $host|awk -F":" '{print $2}')    
        curl  --cacert $CONF_CRT_PATH/master/ca.crt --cert $CONF_CRT_PATH/master/master.etcd-client.crt --key $CONF_CRT_PATH/master/master.etcd-client.key -XPUT https://master.cluster.local:4001/v2/keys/skydns/local/cluster/$key -d value="{\"Host\": \"$ip\"}"
    done
}

function replace_template_domain()
{
    for file in $(grep -rl "openshiftapps.com" /usr/share/openshift/examples/*); do 
        sed -i "s/openshiftapps.com/$CONF_APP_DOMAIN/" $file
        oc replace -n openshift -f $file
    done
}


function configure_nfs_service()
{
    yum_install_or_exit nfs-utils
    mkdir -p /var/export/regvol
    chown nfsnobody:nfsnobody /var/export/regvol
    chmod 700 /var/export/regvol
        # add no_wdelay as workaround for BZ#1277356
    echo "/var/export/regvol *(rw,sync,all_squash,no_wdelay)" >> /etc/exports
    systemctl enable rpcbind nfs-server
    systemctl restart rpcbind nfs-server nfs-lock 
    systemctl restart nfs-idmap


    iptables -N OS_NFS_ALLOW
    rulenum=$(iptables -L INPUT --line-number|grep REJECT|head -n 1|awk '{print $1}')
    iptables -I INPUT $rulenum -j OS_NFS_ALLOW
    iptables -I OS_NFS_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT
    iptables -I OS_NFS_ALLOW -p tcp -m state --state NEW -m tcp --dport 2049 -j ACCEPT
    iptables -I OS_NFS_ALLOW -p tcp -m state --state NEW -m tcp --dport 20048 -j ACCEPT
    iptables -I OS_NFS_ALLOW -p tcp -m state --state NEW -m tcp --dport 50825 -j ACCEPT
    iptables -I OS_NFS_ALLOW -p tcp -m state --state NEW -m tcp --dport 53248 -j ACCEPT

    # save rules and make sure iptables service is active and enabled
    /usr/libexec/iptables/iptables.init save || exit 1
    systemctl is-enabled iptables && systemctl is-active iptables || exit 1

    sed -i 's/RPCMOUNTDOPTS=.*/RPCMOUNTDOPTS="-p 20048"/' /etc/sysconfig/nfs
    sed -i 's/STATDARG=.*/STATDARG="-p 50825"/' /etc/sysconfig/nfs
    echo "fs.nfs.nlm_tcpport=53248" >>/etc/sysctl.conf
    echo "fs.nfs.nlm_udpport=53248" >>/etc/sysctl.conf
    sysctl -p
    systemctl restart nfs
    setsebool -P virt_use_nfs=true
}

function configure_registry_to_ha()
{
    cat >${CONF_CRT_PATH}/pv.json <<EOF
{
  "apiVersion": "v1",
  "kind": "PersistentVolume",
  "metadata": {
    "name": "registry-volume"
  },
  "spec": {
    "capacity": {
        "storage": "17Gi"
        },
    "accessModes": [ "ReadWriteMany" ],
    "nfs": {
        "path": "/var/export/regvol",
        "server": "$(hostname -f)"
    }
  }
}
EOF

    cat >${CONF_CRT_PATH}/pvc.json<<EOF
{
  "apiVersion": "v1",
  "kind": "PersistentVolumeClaim",
  "metadata": {
    "name": "registry-claim"
  },
  "spec": {
    "accessModes": [ "ReadWriteMany" ],
    "resources": {
      "requests": {
        "storage": "17Gi"
      }
    }
  }
}
EOF
    oc create -f ${CONF_CRT_PATH}/pv.json
    oc create -f ${CONF_CRT_PATH}/pvc.json
    oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim --claim-name=registry-claim --name=registry-storage
    oc scale --replicas=2 dc/docker-registry
    
}

function configure_ldap_source()
{
    rm -rf basicauthurl
    mkdir -p basicauthurl/
    cp /etc/yum.repos.d/rhel.repo basicauthurl/
    cat >basicauthurl/Dockerfile <<EOF
FROM $CONF_KERBEROS_BASE_DOCKER_IMAGE
ADD rhel.repo /etc/yum.repos.d/rhel.repo
RUN yum install -y wget mod_ldap tar httpd mod_ssl php mod_auth_kerb mod_auth_mellon mod_authnz_pam
RUN sed -i "/\[realms/,/\[/ s/kdc =.*/kdc = $CONF_KERBEROS_KDC/" /etc/krb5.conf
RUN sed -i "/\[realms/,/\[/ s/admin_server =.*/admin_server = $CONF_KERBEROS_ADMIN/" /etc/krb5.conf
RUN sed -i "s/^#//" /etc/krb5.conf
RUN wget $CONF_KERBEROS_KEYTAB_URL -O /etc/http.keytab
EOF
    docker build -t docker.io/basicauthurl basicauthurl/

}


function modify_IS_for_testing()
{
  if [ $# -lt 1 ]; then
    echo "Usage: $0 [registry-server]"
    exit 1
  fi

  registry_server="${1}"

  cmd="oc delete is --all -n openshift"
  echo "Command: $cmd"
  eval "$cmd"
  cmd="oc delete images --all"
  echo "Command: $cmd"
  eval "$cmd"

  if [ -d "/usr/share/openshift/examples/" ]; then
     IS_json_base="/usr/share/openshift/examples/"
  elif [ -d "/etc/origin/examples/" ]; then
     IS_json_base="/etc/origin/examples/"
  else
     echo "No valid Image Stream json file dir found!"
     exit 1
  fi

  file1="${IS_json_base}/xpaas-streams/jboss-image-streams.json"
  file2="${IS_json_base}/image-streams/image-streams-rhel7.json"

  [ ! -f "${file1}.bak" ] && cp "${file1}" "${file1}.bak"
  [ ! -f "${file2}.bak" ] && cp "${file2}" "${file2}.bak"

  #for line_num in $(grep -n 'name' ${file1} | grep -v 'latest' | grep -v '[0-9]",' | grep -v 'jboss-image-streams' | awk -F':' '{print $1}'); do
  #  sed -i "${line_num}s|\(.*\)|\1,\"annotations\": { \"openshift.io/image.insecureRepository\": \"true\"}|g" ${file1}
  #done

  #for line_num in $(grep -n 'name' ${file2} | grep -v 'latest' | grep -v '[0-9]",' | awk -F':' '{print $1}'); do
  #for line_num in $(grep -n 'name' ${file2} | grep -v 'latest' | grep -v '"[0-9]' | awk -F':' '{print $1}'); do
  #  sed -i "${line_num}s|\(.*\)|\1\"annotations\": { \"openshift.io/image.insecureRepository\": \"true\"},|g" ${file2}
  #done

  if openshift version | grep -q "openshift v3.1.[0-9].[0-9]-"; then
    # when it is v3.1.z version
    for file in ${file1} ${file2}; do
      sed -i "s/registry.access.redhat.com/${registry_server}/g" ${file}
      oc create -f ${file} -n openshift
    done
    for i in ruby nodejs perl php python mysql postgresql mongodb jenkins jboss-amq-62 jboss-datagrid65-openshift jboss-decisionserver62-openshift jboss-eap64-openshift jboss-webserver30-tomcat7-openshift jboss-webserver30-tomcat8-openshift; do
      oc patch is ${i} -p '{"metadata":{"annotations":{"openshift.io/image.insecureRepository":"true"}}}' -n openshift
    done
  else
    # when it is v3.2 version
    oc create -f ${file1} -n openshift
    sed -i "s/registry.access.redhat.com/${registry_server}/g" ${file2}
    sed -i '/from/i\"importPolicy\"\:\ \{\"insecure\"\:\ true\}\,' ${file2}
    oc create -f ${file2} -n openshift
  fi
}

function confiugre_kerberos()
{
    yum install httpd mod_ssl apr-util-openssl mod_auth_kerb  -y
    oadm create-api-client-config --certificate-authority='/etc/origin/master/ca.crt' \
        --client-dir='/etc/origin/master/authproxy' \
        --signer-cert='/etc/origin/master/ca.crt' \
        --signer-key='/etc/origin/master/ca.key' \
        --signer-serial='/etc/origin/master/ca.serial.txt' \
        --user='authproxy'
    host_name=$(hostname)
    pushd /etc/origin/master
    \cp master.server.crt /etc/pki/tls/certs/localhost.crt
    \cp master.server.key /etc/pki/tls/private/localhost.key
    \cp ca.crt /etc/pki/CA/certs/ca.crt
    cat authproxy/authproxy.crt \
        authproxy/authproxy.key > \
        /etc/pki/tls/certs/authproxy.pem
    popd
    cat  >/etc/httpd/conf.d/openshift.conf <<EOF
#LoadModule auth_form_module modules/mod_auth_form.so
#LoadModule session_module modules/mod_session.so
#LoadModule request_module modules/mod_request.so

# Nothing needs to be served over HTTP.  This virtual host simply redirects to
# HTTPS.
<VirtualHost *:80>
  DocumentRoot /var/www/html
  RewriteEngine              On
  RewriteRule     ^(.*)$     https://%{HTTP_HOST}$1 [R,L]
</VirtualHost>

<VirtualHost *:443>
  # This needs to match the certificates you generated.  See the CN and X509v3
  # Subject Alternative Name in the output of:
  # openssl x509 -text -in /etc/pki/tls/certs/localhost.crt
  ServerName $host_name

  DocumentRoot /var/www/html
  SSLEngine on
  SSLCertificateFile /etc/pki/tls/certs/localhost.crt
  SSLCertificateKeyFile /etc/pki/tls/private/localhost.key
  SSLCACertificateFile /etc/pki/CA/certs/ca.crt

  SSLProxyEngine on
  SSLProxyCACertificateFile /etc/pki/CA/certs/ca.crt
  # It's critical to enforce client certificates on the Master.  Otherwise
  # requests could spoof the X-Remote-User header by accessing the Master's
  # /oauth/authorize endpoint directly.
  SSLProxyMachineCertificateFile /etc/pki/tls/certs/authproxy.pem

  # Send all requests to the console
  RewriteEngine              On
  RewriteRule     ^/console(.*)$     https://%{HTTP_HOST}:8443/console$1 [R,L]

  # In order to using the challenging-proxy an X-Csrf-Token must be present.
  RewriteCond %{REQUEST_URI} ^/challenging-proxy
  RewriteCond %{HTTP:X-Csrf-Token} ^$ [NC]
  RewriteRule ^.* - [F,L]

  <Location /challenging-proxy/oauth/authorize>
    # Insert your backend server name/ip here.
    ProxyPass https://$host_name:8443/oauth/authorize
  </Location>

  <Location /login-proxy/oauth/authorize>
    # Insert your backend server name/ip here.
    ProxyPass https://$host_name:8443/oauth/authorize

    # mod_auth_form providers are implemented by mod_authn_dbm, mod_authn_file,
    # mod_authn_dbd, mod_authnz_ldap and mod_authn_socache.
    AuthType Kerberos
    AuthName openshift
    ErrorDocument 401 /login.html
  </Location>

  <ProxyMatch /oauth/authorize>
    AuthType Kerberos
    KrbMethodNegotiate on
    KrbMethodK5Passwd on
    KrbServiceName Any
    KrbAuthRealms EXAMPLE.COM
    Krb5Keytab /etc/origin/http.keytab
    KrbSaveCredentials off

    AuthName openshift
    Require valid-user
    RequestHeader set X-Remote-User %{REMOTE_USER}s

    # For ldap:
    # AuthBasicProvider ldap
    # AuthLDAPURL "ldap://ldap.example.com:389/ou=People,dc=my-domain,dc=com?uid?sub?(objectClass=*)"

    # It's possible to remove the mod_auth_form usage and replace it with
    # something like mod_auth_kerb, mod_auth_gsspai or even mod_auth_mellon.
    # The former would be able to support both the login and challenge flows
    # from the Master.  Mellon would likely only support the login flow.

    # For Kerberos
    # yum install mod_auth_gssapi
    # AuthType GSSAPI
    # GssapiCredStore keytab:/etc/httpd.keytab
  </ProxyMatch>

</VirtualHost>

RequestHeader unset X-Remote-User
EOF

    pushd /var/www/html/
    wget https://raw.githubusercontent.com/openshift/openshift-extras/master/misc/form_auth/login.html
    wget https://raw.githubusercontent.com/openshift/openshift-extras/master/misc/form_auth/loggedout.html
    chmod -Rf 0777 *
    popd
    wget $CONF_KERBEROS_KEYTAB_URL -O /etc/origin/http.keytab
    chown apache:apache /etc/origin/http.keytab
     cat > /etc/krb5.conf <<EOF
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
# default_realm = EXAMPLE.COM
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
 EXAMPLE.COM = {
  kdc = $CONF_KERBEROS_KDC
  admin_server = $CONF_KERBEROS_ADMIN
 }

[domain_realm]
 .example.com = EXAMPLE.COM
 example.com = EXAMPLE.COM
EOF
    systemctl restart httpd

}


#CONF_HOST_LIST=vaule
#CONF_IP_LIST=value
#CONF_HOST_DOMAIN=value
#CONF_APP_DOMAIN=value
#CONF_RHEL_BASE_REPO=value
#CONF_INTERFACE=value
#CONF_DNS_IP=value
#USE_OPENSTACK_DNS=value
#CONF_AUTH_TYPE=value
#CONF_CRT_PATH=value
#CONF_IMAGE_PRE=value
#CONF_KERBEROS_KDC=value
#CONF_KERBEROS_ADMIN=value
#CONF_KERBEROS_KEYTAB_URL=value
#CONF_KERBEROS_BASE_DOCKER_IMAGE=value
#CONF_ROUTER_NODE_TYPE=value
#CONF_PUDDLE_REPO=value
interface="${CONF_INTERFACE:-eth0}"
nameservers="$(awk '/nameserver/ { printf "%s; ", $2 }' /etc/resolv.conf)"
named_hostname=ns1.$CONF_HOST_DOMAIN

function update_playbook_rpms()
{
    cat <<EOF >/etc/yum.repos.d/ose-devel.repo
[ose-devel]
name=ose-devel
baseurl=${CONF_PUDDLE_REPO}
enabled=1
gpgcheck=0
EOF
    rpm -q atomic-openshift-utils && yum update openshift-ansible* -y || yum install atomic-openshift-utils -y
}

function garbage_clean_up()
{
        cat << EOF > /etc/cron.hourly
oadm prune builds --keep-complete=5 --keep-failed=1 --keep-younger-than=1h0m0s --orphans=true --confirm=true
oadm prune deployments --keep-complete=5 --keep-failed=1 --keep-younger-than=1h0m0s --orphans=true --confirm=true
EOF
}

case $1 in
    wait_cloud_init)
        wait_cloud_init
        ;;
    configure_dns)
        #configure_repos
        install_named_pkg
        configure_bind
        #clean_repos
        ;;
    configure_dns_resolution)
        configure_dns_resolution
        ;;
    create_router_registry)
        create_router_registry
        ;;
    configure_hosts)
        configure_hosts
        ;;
    configure_shared_dns)
        configure_shared_dns
        ;;
    add_skydns_hosts)
        add_skydns_hosts
        ;;
    replace_template_domain)
        replace_template_domain
        ;;
    configure_nfs_service)
        configure_nfs_service
        ;;
    configure_registry_to_ha)
        configure_registry_to_ha
        ;;
    configure_repos)
        clean_repos
        configure_repos
        yum update -y
        ;;
    modify_IS_for_testing)
        modify_IS_for_testing "$2"
        ;;
    update_playbook_rpms)
        update_playbook_rpms
        ;;

    garbage_clean_up)
        garbage_clean_up
        ;;

    confiugre_kerberos)
        confiugre_kerberos
        ;;
    *)
        echo "Invalid Action: $1"
esac
