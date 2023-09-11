# wwwhisper Buildpack for Heroku

Provides application-independent access control for Heroku-hosted
web applications. The access control is based on verified email
addresses of visitors.

The buildpack requires the Heroku [wwwhisper
add-on](https://elements.heroku.com/addons/wwwhisper).

The buildpack installs and runs an nginx proxy that communicates with
the wwwhisper service to authenticate and authorize
visitors. Authorized requests are passed to the app, unauthorized ones
are rejected with 401 or 403 HTTP errors.

nginx listens on an externally accessible $PORT configured by the
Heroku dyno manager. The $PORT passed to the application is reassigned
to a private port that is not externally accessible.

See also [the documentation on
Heroku](https://devcenter.heroku.com/articles/wwwhisper).


## Buildpack Development

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

* nginx configs are modified to perform authentication/authorization
  before requests are forwarded to the application. The buildpack
  doesn't currently support supplying a custom `nginx.conf`.

* Configuration templates are changed to use `envsubst` instead of
  more powerful `erb` templates. `erb` required the buildpack to
  install Ruby on Heroku stack 22.


### Upgrading Nginx or changing compilation options

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

### Starting the buildpack locally

Get `WWWHISPER_URL` by running `heroku config` for a Heroku app with
the wwwhisper add-on enabled.

```
WWWHISPER_URL="PUT_YOUR_WWWHISPER_URL_HERE" ./scripts/devel_start
```

## Authors, License, and Copyright

The original nginx buildpack was created by Ryan R. Smith:

*Copyright (c) 2013 Ryan R. Smith \
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.*

For a list of further contributors, see
[heroku-buildpack-nginx](https://github.com/heroku/heroku-buildpack-nginx)
repository history.

Changes for wwwhisper are Copyright (C) 2023 Jan Wrobel, jan@mixedbit.org.

