# wwwhisper Buildpack for Heroku

Provides application-independent access control for Heroku-hosted
web applications. The access control is based on verified email
addresses of visitors.

## Enabling the Buildpack

The buildpack requires the Heroku [wwwhisper
add-on](https://elements.heroku.com/addons/wwwhisper).

To enable the buildpack, in your application folder run:

```
heroku addons:create wwwhisper:team3[or team10 team20 plus50 plus100 ...] [--admin=your_email]
heroku buildpacks:add auth/wwwhisper
```

There is no need to modify your application code, but you need to push
the new version of your application for the buildpack to be compiled:

```
git commit -a --allow-empty -m "Enable wwwhisper buildpack.";
git push heroku main # or master
```

After these operations, opening your application URL will show a login
prompt. Enter your Heroku application owner email to get receive a
login link.

## Technical Details

The buildpack installs and runs an nginx proxy that communicates with
the wwwhisper service to authenticate and authorize
visitors. Authorized requests are passed to the app, unauthorized ones
are rejected with 401 or 403 HTTP errors.

nginx listens on an externally accessible $PORT configured by the
Heroku dyno manager. The $PORT passed to the application is reassigned
to a private port that is not externally accessible.

See also [devel-notes.md](./devel-notes.md).

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

