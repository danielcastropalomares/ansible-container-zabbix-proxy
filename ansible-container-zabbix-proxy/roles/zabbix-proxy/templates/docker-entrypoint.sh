#!/bin/bash
ZBX_CONFIG=/etc/zabbix/zabbix_proxy.conf
escape_spec_char() {
    local var_value=$1

    var_value="${var_value//\\/\\\\}"
    var_value="${var_value//[$'\n']/}"
    var_value="${var_value//\//\\/}"
    var_value="${var_value//./\\.}"
    var_value="${var_value//\*/\\*}"
    var_value="${var_value//^/\\^}"
    var_value="${var_value//\$/\\\$}"
    var_value="${var_value//\&/\\\&}"
    var_value="${var_value//\[/\\[}"
    var_value="${var_value//\]/\\]}"

    echo $var_value
}

update_config_var() {
    local config_path=$1
    local var_name=$2
    local var_value=$3
    local is_multiple=$4

    if [ ! -f "$config_path" ]; then
        echo "**** Configuration file '$config_path' does not exist"
        return
    fi

    echo -n "** Updating '$config_path' parameter \"$var_name\": '$var_value'... "

    # Remove configuration parameter definition in case of unset parameter value
    if [ -z "$var_value" ]; then
        sed -i -e "/^$var_name=/d" "$config_path"
        echo "removed"
        return
    fi

    # Remove value from configuration parameter in case of double quoted parameter value
    if [ "$var_value" == '""' ]; then
        sed -i -e "/^$var_name=/s/=.*/=/" "$config_path"
        echo "undefined"
        return
    fi

    # Escaping characters in parameter value
    var_value=$(escape_spec_char "$var_value")

    if [ "$(grep -E "^$var_name=" $config_path)" ] && [ "$is_multiple" != "true" ]; then
        sed -i -e "/^$var_name=/s/=.*/=$var_value/" "$config_path"
        echo "updated"
    elif [ "$(grep -Ec "^# $var_name=" $config_path)" -gt 1 ]; then
        sed -i -e  "/^[#;] $var_name=$/i\\$var_name=$var_value" "$config_path"
        echo "added first occurrence"
    else
        sed -i -e "/^[#;] $var_name=/s/.*/&\n$var_name=$var_value/" "$config_path"
        echo "added"
    fi

}
if [ -n "${ZBX_SERVER_HOST}" ] ; then
    echo "** configure Server Host"
    update_config_var $ZBX_CONFIG "Server" "${ZBX_SERVER_HOST}"
fi
if [ -n "${ZBX_PROXYOFFLINEBUFFER}" ] ; then
    echo "** configure OfflineBuffer"
    update_config_var $ZBX_CONFIG "ProxyOfflineBuffer" "${ZBX_PROXYOFFLINEBUFFER}"
fi
if [ -z "${ZBX_HOSTNAME}" ] ; then
    echo "** configure Hostnme"
   update_config_var $ZBX_CONFIG "Hostname" ""
   update_config_var $ZBX_CONFIG "HostnameItem" "system.hostname"
fi
if [ -n "${DB_SERVER_DBNAME}" ] ; then
    echo "** configure DBName"
    update_config_var $ZBX_CONFIG "DBName" "${DB_SERVER_DBNAME}" 
fi
echo "** Starting Zabbix proxy"
exec su zabbix -s "/bin/bash" -c "/usr/sbin/zabbix_proxy --foreground -c /etc/zabbix/zabbix_proxy.conf"
cat /var/log/zabbix/*
