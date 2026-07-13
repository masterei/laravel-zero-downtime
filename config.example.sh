#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Framework
# -----------------------------------------------------------------------------

readonly DEPLOY_VERSION="1.0.0"

# -----------------------------------------------------------------------------
# Deployment
# -----------------------------------------------------------------------------

readonly RELEASES_TO_KEEP=5

# -----------------------------------------------------------------------------
# Runtime
# -----------------------------------------------------------------------------

readonly PHP_VERSION="8.2"
readonly RUNTIME_USER="www-data"

# -----------------------------------------------------------------------------
# Application Paths
# -----------------------------------------------------------------------------

# Root application directory.
readonly BASE="/var/www/$APP_NAME"

# Directory containing all application releases.
readonly RELEASES="$BASE/releases"

# Directory containing persistent shared resources.
readonly SHARED="$BASE/shared"

# Symlink to the active application release.
readonly CURRENT="$BASE/current"
