Overview
============

This is a Logtail backend for logtail which lets you send lager logs to your logtail account. Lager_loggly was copied and edited so i could achieve this, special thanks to them for that!

## Configuration
Add the following to rebar3.config:

	{lager_logtail, "0.2.0"}

Configure a Lager handler like the following :

	{lager_logtail_backend, [Level, MaxRetries, RetryInterval, LogtailToken]}

* Level - The lager level at which the  backend accepts messages (eg. using ‘info’ would send all messages at info level or above into syslog)
* MaxRetries - The maximum number of retries the backend will do before giving up on Logtail
* RetryInterval - The interval at which each retry is performed. i.e. Retries 5 and Interval 3 means that it will try a maximum of 5 times with 3 seconds apart
* LogtailToken - This is your unique Logtail token


An example might look something like this:

	{lager_logtail_backend, [info, 5, 3, <OWN_TOKEN>]}

Refer to Lager’s documentation for further information on configuring handlers.

## Links
Hex page: https://hex.pm/packages/lager_logtail
Github page: https://github.com/qualia91/lager_logtail