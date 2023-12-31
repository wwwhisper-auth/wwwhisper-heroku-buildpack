#!/usr/bin/env bash
#
# 1) Replaces the TCP $PORT exported to the app with a TCP port not
# available from the outside world. Heroku platform guarantees that
# only the web $PORT can be reached from the outside: 'The Common
# Runtime provides strong isolation by firewalling all dynos off from
# one another. The only traffic that can reach a dyno is web requests
# forwarded from the router to web processes listening on the port
# number specified in the $PORT environment variable.'
# https://devcenter.heroku.com/articles/dynos#common-runtime-networking
#
# 2) Starts nginx in background to listen on the original $PORT and to
# authenticate and authorize requests. Authorized requests are proxied
# to the web application.
#
#
# If this startup script fails, the whole app startup process
# correctly crashes, which ensures that app with the wwwhisper
# buildpack will not be started on the original port (this would
# bypass authorization).


# .profile.d scripts are also sourced by `heroku ps:exec`, in such
# case $PORT is not set and this script should do nothing.
if [[ -z "${PORT}" ]]
then
  return 0
fi

WWWHISPER_NGINX_PID_FILE=`pwd`/wwwhisper/logs/nginx.pid

function wwwhisper_log() {
  echo "buildpack=wwwhisper $*"
}

function wwwhisper_fatal() {
  wwwhisper_log "$*"
  exit 1
}

function wwwhisper_host() {
  echo https://`echo ${WWWHISPER_URL}|tr @ '\n'| tail -n1`
}

function wwwhisper_basic_auth() {
  local proto_credentials=`echo ${WWWHISPER_URL} |tr @ '\n'|head -n1`
  # strip protocol prefix
  local credentials=${proto_credentials#"https://"}
  echo -n "${credentials}" | base64
}

# When SIGTERM is delivered, wait until nginx terminates and then
# re-raise the SIGTERM to terminate the web application.
function wwwhisper_sigterm_handler() {
  wwwhisper_log "SIGTERM received, waiting for nginx to terminate."
  # nginx removes the pid file when it exits.
  while [[ -f ${WWWHISPER_NGINX_PID_FILE} ]] ; do
    sleep 0.2
  done
  wwwhisper_log "nginx terminated."
  # Remove the trap and re-raise the signal
  trap - SIGTERM
  kill -SIGTERM $$
}

function wwwhisper_create_nginx_configs() {
  local public_port=$1

  # Set basic auth credentials to access the wwwhisper service.
  WWWHISPER_HOST=$(wwwhisper_host) \
  WWWHISPER_BASIC_AUTH=$(wwwhisper_basic_auth) \
  envsubst '$WWWHISPER_HOST $WWWHISPER_BASIC_AUTH' \
    < wwwhisper/config/wwwhisper_proxy.template.conf \
    > wwwhisper/config/wwwhisper_proxy.conf
  if (( $? != 0 )); then
    wwwhisper_fatal "Failed to create configuration files."
  fi

  # Set port to listen to in the config.
  PRIVATE_PORT=${PORT} \
  PUBLIC_PORT=${public_port} \
  envsubst '$PRIVATE_PORT $PUBLIC_PORT' \
    < wwwhisper/config/nginx.template.conf \
    > wwwhisper/config/nginx.conf
  if (( $? != 0 )); then
    wwwhisper_fatal "Failed to create configuration files(2)."
  fi

  if [[ -z "${WWWHISPER_NO_OVERLAY}" ]]; then
    cp wwwhisper/config/wwwhisper_overlay.template.conf \
       wwwhisper/config/wwwhisper_overlay.conf
  else
    # Use an empty file instead of overlay enabling directives.
    echo "" > wwwhisper/config/wwwhisper_overlay.conf
  fi

  if (( $? != 0 )); then
    wwwhisper_fatal "Failed to create configuration files(3)."
  fi

  wwwhisper_log "Created configuration files for nginx authorization."
}

function wwwhisper_main() {
  local public_port=${PORT}
  # Web app should use a private port, not accessible externally.
  # Reasign the PORT.
  if [[ "${public_port}" != "10080" ]]; then
    export PORT=10080
  else
    export PORT=10081
  fi
  wwwhisper_log "Remapped web app external port to private port ${PORT}."

  local web_app_pid=$$

  if [[ -z "${WWWHISPER_URL}" ]]; then
    wwwhisper_fatal 'wwwhisper add-on must be enabled to use this buildpack.'
  fi

  wwwhisper_create_nginx_configs $public_port

  function wwwhisper_run_nginx() {
    wwwhisper_log "Waiting for the app to start listening on port ${PORT}."

    # Loop without any time limit, but Heroku will kill the dyno if
    # it doesn't bind the external port in 60 seconds.
    while ! nc -z localhost ${PORT}; do
      sleep 0.2
    done

    local bin_to_run
    if [[ -z "${WWWHISPER_DEBUG}" ]]; then
      bin_to_run="nginx"
    else
      bin_to_run="nginx-debug"
    fi

    # Do not terminate the subshell with SIGTERM, let nginx handle
    # this signal and terminate gracefully which then terminates the
    # subshell.
    trap "" SIGTERM

    wwwhisper_log "Staring nginx process to authorize requests."
    ./wwwhisper/bin/${bin_to_run} -p wwwhisper -c config/nginx.conf &
    local nginx_pid="$!"

    wait -f ${nginx_pid}
    local exit_code=$?

    # Dyno manager monitors web app process, not nginx process, so
    # when nginx fails, we terminate web app process. This way dyno
    # manager notices dyno failure and restarts the dyno (it would
    # eventually do it anyway, because $PORT stops accepting requests,
    # but terminating web app process makes it quicker).
    #
    # If nginx is terminated by Heroku dyno manager (SIGTERM or
    # SIGQUIT), exit code is 0 and we don't resend this signal,
    # because the dyno manager already delivers it to all the
    # processes.
    if (( ${exit_code} != 0 )); then
      wwwhisper_log "nginx failed with code ${exit_code}," \
                    "killing web app with SIGTERM."
      # In case nginx crashed without removing the pid file.
      rm -f ${WWWHISPER_NGINX_PID_FILE}
      kill -SIGTERM ${web_app_pid} >/dev/null
      if (( $? == 0 )); then
        # SIGTERM was delivered successfully, deliver SIGKILL after some time.
        sleep 40
        wwwhisper_log "Killing web app with SIGKILL."
        kill -SIGKILL ${web_app_pid} >/dev/null
      fi
    fi

    wwwhisper_log "exiting"
    exit 1
  }

  trap wwwhisper_sigterm_handler SIGTERM
  wwwhisper_run_nginx &
}

wwwhisper_main

# Do not pass WWWHISPER_URL to the app. This is in case wwwhisper
# buildpack is enabled for an app that already uses wwwhisper
# middleware for node.js or Ruby. Lack of WWWHISPER_URL will cause the
# middleware to show an error (such setup doesn't make sense, as it
# would make two auth requests per each incomming request).
unset WWWHISPER_URL
unset -f wwwhisper_host
unset -f wwwhisper_basic_auth
unset -f wwwhisper_create_nginx_configs

