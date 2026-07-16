#!/usr/bin/env bash

# Linux user that owns the application files and executes deployments.
readonly APP_OWNER="deploy"

# Linux user used by the web server to execute the application.
readonly RUNTIME_USER="www-data"

# Number of previous releases to retain after each deployment.
readonly RELEASES_TO_KEEP=5
