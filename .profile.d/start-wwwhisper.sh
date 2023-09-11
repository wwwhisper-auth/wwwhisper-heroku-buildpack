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

function wwwhisper_log() {
  echo "buildpack=wwwhisper $*"
}

function wwwhisper_fatal() {
  wwwhisper_log "$*"
  exit 1
}

function wwwhisper_main() {
  local public_port=${PORT}
  # Web app should use a private port, not accessible externally.
  # Reasign the PORT.
  if [[ "${public_port}" != "10080" ]];
  then
    export PORT=10080
  else
    export PORT=10081
  fi
  wwwhisper_log "Remapped web app external port to private port ${PORT}."

  local web_app_pid=$$;

  # Set port to listen to in the config.
  PRIVATE_PORT=${PORT} \
  PUBLIC_PORT=${public_port} \
  envsubst '$PRIVATE_PORT $PUBLIC_PORT' \
    < wwwhisper/config/nginx.template.conf \
    > wwwhisper/config/nginx.conf
  if (( $? != 0 )); then
    wwwhisper_fatal "Failed to create configuration files."
  fi

  wwwhisper_log "Created configuration files for nginx authorization."

  wwwhisper_run_nginx() {
    wwwhisper_log "Waiting for the app to start listening on port ${PORT}."

    # Loop without any time limit, but Heroku will kill the dyno if
    # it doesn't bind the external port in 60 seconds.
    while ! nc -z localhost ${PORT}; do
      sleep 0.2
    done

    local bin_to_run;
    if [[ -z "${WWWHISPER_DEBUG}" ]]
    then
      bin_to_run="nginx"
    else
      bin_to_run="nginx-debug"
    fi

    wwwhisper_log "Staring nginx process to authorize requests."
    ./wwwhisper/bin/${bin_to_run} -p wwwhisper -c config/nginx.conf &
    local nginx_pid="$!"

    wait ${nginx_pid}
    local exit_code=$?

    # Dyno manager monitors web app process, not nginx process, so
    # when nginx fails, we terminate web app process. This way dyno
    # manager notices dyno failure and restarts the dyno (it would
    # eventually do it anyway, because $PORT would stop accepting
    # requests, but terminating web app process makes it quicker).
    #
    # If nginx is terminated by Heroku dyno manager (SIGTERM or
    # SIGQUIT), exit code is 0 and we don't resend this signal,
    # because the dyno manager already delivers it to all the
    # processes.
    if (( ${exit_code} != 0 )); then
      wwwhisper_log "nginx failed with code ${exit_code}," \
                    "killing web app with SIGTERM."
      kill -SIGTERM ${web_app_pid} >/dev/null
      if (( $? == 0 )); then
        # Sigterm was delivered successfully, deliver sigkill after some time.
        sleep 40
        wwwhisper_log "Killing web app with SIGKILL."
        kill -SIGKILL ${web_app_pid} >/dev/null
      fi
    fi;

    wwwhisper_log "exiting"
    exit 1;
  }

  wwwhisper_run_nginx &
}

wwwhisper_main

# Cleanup globals to prevent potential interference with other
# scripts.
unset -f wwwhisper_main
unset -f wwwhisper_run_nginx
unset -f wwwhisper_log
unset -f wwwhisper_fatal

# Do not pass WWWHISPER_URL to the app. This is in case wwwhisper
# buildpack is enabled for an app that already uses wwwhisper
# middleware for node.js or Ruby. Lack of WWWHISPER_URL will cause the
# middleware to show an error (such setup doesn't make sense, as it
# would make two auth requests per each incomming request).
unset WWWHISPER_URL
