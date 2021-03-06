# identity

Based on the concept of web-based Heroku user management not belonging in the API over the long-term, Identity pulls session-based authentication out of API and provides a drop-in replacement for the Heroku OAuth API that OAuth clients can use instead.

OAuth session management is achieved by a "meta-OAuth" provider implementation. Identity first authorizes itself to get access to a user's account, then authorizes other consumers that use it as a target by proxying calls to the API (but using only the JSON authentication APIs). The one caveat here is that Identity must have the `can_manage_authorizations` flag set for it in API.

## Issue and Security Vulnerability Reporting

In general Heroku makes extensive use of GitHub issues, and for the
vast majority of bugs we encourage reporters to use them here.  For
the limited case of exploitable security vulnerabilities, we ask
researchers to report problems to security@heroku.com.
[We also have general reporting guidelines, which list the security team's PGP key](https://www.heroku.com/policy/security#vuln_report).

## Operations

See [operations](https://github.com/heroku/identity/tree/master/operations.md).

## Usage

``` bash
bundle install
cp .env.sample .env # And then edit it
foreman start
# check localhost:5000
```

## Platform Install

```
heroku config:add COOKIE_ENCRYPTION_KEY=...
heroku config:add DASHBOARD_URL="https://dashboard.heroku.com"
heroku config:add HEROKU_API_URL="https://api.heroku.com"
heroku config:add HEROKU_OAUTH_ID=...
heroku config:add HEROKU_OAUTH_SECRET=...
git push heroku master
```

Your OAuth client will also need to be able to manage authorizations, which is set by an internal flag. Get [heroku-sudo](https://github.com/heroku/heroku-sudo), and flag your client:

```
heroku sudo clients:update <oauth-client-id> --can-manage-authorizations true
```

## Deploying

### Preparation/Setup (only needed once, substitute your email address):

```
export HEROKU_EMAIL_ADDRESS=...
heroku sudo sharing:add $HEROKU_EMAIL_ADDRESS -a id-staging
heroku git:remote -a id-staging -r staging
heroku sudo sharing:add $HEROKU_EMAIL_ADDRESS -a id-production
heroku git:remote -a id-production -r production
```

### Deployment

Note: requires api-admin (install/build from http://github.com/heroku/api-admin)

```
rake test
git push staging master
api-test-login --staging
git push production master
api-test-login --production
```

## Debugging Production

### Honeybadger

Uncaught errors are sent to Honeybadger, which can be accessed via:

    heroku addons:open honeybadger -a id-staging
    heroku addons:open honeybadger -a id-production

In case of a bad API or Identity deploy and SSO is down, there is also a backdoor into the Honeybadger projects. Get credentials from LastPass.

### Logs

Identity keeps fairly detailed logs for each request:

    heroku logs --tail -n 1000 -a id-production

### Splunk

Identity's logs are also drained to the [platform Splunk installation](https://splunk.herokai.com). Identity also injects its request IDs into the Heroku API, so if the UUID of any given Identity request is obtained (i.e. find the `id=<uuid>` attribute in any emitted log line), it can used to bring up all corresponding Identity _and_ API logs in Splunk.

## Test

``` bash
rake test
```
