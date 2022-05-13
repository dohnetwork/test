#!/bin/bash

# Update nginx to match worker_processes to no. of cpu's
procs=$(cat /proc/cpuinfo | grep processor | wc -l)
sed -i -e "s/worker_processes  1/worker_processes $procs/" /etc/nginx/nginx.conf

# Always chown webroot for better mounting
chown -Rf nginx:nginx /usr/share/nginx/html

# Start supervisord and services
agent_conf_file="/etc/amplify-agent/agent.conf"
agent_log_file="/var/log/amplify-agent/agent.log"
nginx_status_conf="/etc/nginx/conf.d/stub_status.conf"
api_key=""
amplify_imagename=""

# Launch nginx
echo "starting nginx ..."
#nginx -g "daemon off;" &

nginx_pid=$!

test -n "${API_KEY}" && \
    api_key=${API_KEY}

test -n "${AMPLIFY_IMAGENAME}" && \
    amplify_imagename=${AMPLIFY_IMAGENAME}

if [ -n "${api_key}" -o -n "${amplify_imagename}" ]; then
    echo "updating ${agent_conf_file} ..."

    if [ ! -f "${agent_conf_file}" ]; then
	test -f "${agent_conf_file}.default" && \
	cp -p "${agent_conf_file}.default" "${agent_conf_file}" || \
	{ echo "no ${agent_conf_file}.default found! exiting."; exit 1; }
    fi

    test -n "${api_key}" && \
    echo " ---> using api_key = ${api_key}" && \
    sh -c "sed -i.old -e 's/api_key.*$/api_key = $api_key/' \
	${agent_conf_file}"

    test -n "${amplify_imagename}" && \
    echo " ---> using imagename = ${amplify_imagename}" && \
    sh -c "sed -i.old -e 's/imagename.*$/imagename = $amplify_imagename/' \
	${agent_conf_file}"

    test -f "${agent_conf_file}" && \
    chmod 644 ${agent_conf_file} && \
    chown nginx ${agent_conf_file} > /dev/null 2>&1

    test -f "${nginx_status_conf}" && \
    chmod 644 ${nginx_status_conf} && \
    chown nginx ${nginx_status_conf} > /dev/null 2>&1
fi

if ! grep '^api_key.*=[ ]*[[:alnum:]].*' ${agent_conf_file} > /dev/null 2>&1; then
    echo "no api_key found in ${agent_conf_file}! exiting."
fi

echo "starting amplify-agent ..."
service amplify-agent start > /dev/null 2>&1 < /dev/null

if [ $? != 0 ]; then
    echo "couldn't start the agent, please check ${agent_log_file}"
    exit 1
fi

wait ${nginx_pid}

echo "nginx master process has stopped, exiting."

/usr/local/bin/supervisord -n -c /etc/supervisord.conf
