# wwwhisper Buildpack for Heroku

Provides application-independent access control for Heroku-hosted
web applications. The access control is based on verified email
addresses of visitors.

The buildpack works with Heroku Cedar stack (Heroku Common Runtime and
Cedar Private spaces). Heroku new generation Fir buildpack is at
https://github.com/wwwhisper-auth/wwwhisper-cnb

## Enabling the Buildpack

The buildpack requires the Heroku [wwwhisper
add-on](https://elements.heroku.com/addons/wwwhisper).

To enable the buildpack, in your application folder run:

```
heroku addons:create wwwhisper:team-3[or team-10 team-20 plus-50 plus-100 ...] [--admin=your_email]
heroku buildpacks:add auth/wwwhisper
```

There is no need to modify your application code, but you need to push
the new version of your application for the buildpack to be compiled:

```
git commit -a --allow-empty -m "Enable wwwhisper buildpack.";
git push heroku main # or master
```

After these operations, opening your application URL will show a login
prompt. Enter your Heroku application owner email to receive a login
link.

## Technical Details

The buildpack runs a reverse proxy that authenticates and authorizes
visitors. Authorized requests are passed to the app; unauthorized ones
are rejected with 401 or 403 HTTP errors. Sessions and access control
rules used by the proxy are stored by wwwhisper backend. For
efficiency, the proxy caches this data allowing most authorization
decisions to be made locally in sub-millisecond time, without
requiring requests to the wwwhisper backend.

The reverse proxy listens on an externally accessible `PORT` configured
by the Heroku dyno manager. The `PORT` passed to the application is
reassigned to a private port that is not externally accessible.

