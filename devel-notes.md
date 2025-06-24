# Buildpack Development

NOTE: The notes below are relevant only for the original, nginx based
version of the authorization reverse proxy. This version is now
replaced by a custom Go-based authorization reverse proxy. All new
applications use this new Go version. nginx version is still kept, but
will soon be removed.

The buildpack is based on
[heroku-buildpack-nginx](https://github.com/heroku/heroku-buildpack-nginx),
but with substantial modifications:

* nginx is built with the `auth_request` module and a minimal
  number of other modules and dependencies.

* The buildpack uses a `.profile.d` script to configure enviroment,
  start, and monitor nginx as a background job. The $PORT environment
  variable passed to the application is changed to a local, not
  externally accessible port. The script waits for this local port to
  be bound by the application before nginx is started. This way, the
  Heroku Dyno Manager/Vegur router does not pass requests to nginx
  when the application is not yet ready to process them. These changes
  allow to enable the buildpack with a single command (no need to
  modify Procfile and to modify an app to listen on a Unix domain
  socket, as is the case with the original nginx buildpack).

* In accordance with [Heroku
  guidance](https://devcenter.heroku.com/articles/dynos#graceful-shutdown-with-sigterm),
  nginx is terminated gracefully on SIGTERM.

* nginx configs are modified to perform authentication/authorization
  before requests are forwarded to the application. The buildpack
  doesn't currently support supplying a custom `nginx.conf`.

* Configuration templates are changed to use `envsubst` instead of
  more powerful `erb` templates. `erb` required the buildpack to
  install Ruby on Heroku stack 22.


## Upgrading Nginx or changing compilation options

Use only stable, even-numbered [Nginx
releases](https://nginx.org/en/download.html).

Revise the version variables or compilation options in
[scripts/build_nginx](scripts/build_nginx), and then run the builds in
a container (requires Docker) via:

```
$ make build
```

The binaries will be packed into `tar` files and placed in the
repository's root directory. Commit & pull-request the resulting
changes.

## Starting the buildpack locally

Get `WWWHISPER_URL` by running `heroku config` for a Heroku app with
the wwwhisper add-on enabled.

```
WWWHISPER_URL="PUT_YOUR_WWWHISPER_URL_HERE" ./scripts/devel_start
```

## ARM architecture

While Heroku stack 24 images started to support ARM, Heroku Dynos do
not offer ARM machines. It looks like ARM images are currently used
only for running the Heroku stack locally. For this reason the
buildpack doesn't have ARM version for the stack 24 (see this commit
for changes needed to add ARM support in case the need for it arises
https://github.com/heroku/heroku-buildpack-nginx/commit/277ccf20bde7fb69145408ee6dd0bc349a497c6b#diff-76ed074a9305c04054cdebb9e9aad2d818052b07091de1f20cad0bbac34ffb52R13)