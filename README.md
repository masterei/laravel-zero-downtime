# Laravel Zero-Downtime Deployment

A lightweight deployment framework for Laravel applications running on a single VPS, without requiring containerized application deployments.

Applications are packaged as immutable release artifacts and deployed using atomic symlink switching for near zero-downtime deployments. An example GitHub Actions workflow is included.

> **Status:** Production-tested and actively used.

## Quick Start

Assuming the server already satisfies the requirements:

```bash
git clone https://github.com/masterei/laravel-zero-downtime.git
cd laravel-zero-downtime

cp config.example.sh config.sh

# Configure APP_OWNER, RUNTIME_USER, etc.

sudo ./setup.sh my-app

# Populate shared/.env and shared/storage

sudo ./permissions.sh my-app

./deploy.sh \
    my-app \
    20260713153015-a4c9d8e \
    /tmp/my-app-20260713153015-a4c9d8e.tar.gz
```

## Features

- Atomic deployments using symlinks
- Immutable release directories
- Interactive rollback to any retained previous release
- Shared persistent resources (`.env` and `storage`)
- Application-specific deployment hooks
- Automatic cleanup of old releases
- CI/CD agnostic

## Design Philosophy

This project aims to provide a simple, lightweight, and predictable deployment framework for Laravel applications running on a single VPS.

The framework is intentionally opinionated and emphasizes:

- Simplicity over feature completeness
- Immutable releases
- Atomic deployments
- Easy rollbacks
- Minimal server dependencies
- Application-specific deployment hooks

## Directory Structure

After running `setup.sh`, the application directory will look like this:

```text
/var/www/<app-name>
├── current -> releases/<release>
├── releases
│   ├── 20260713153015-a4c9d8e
│   ├── 20260714101532-c91be3f
│   └── ...
└── shared
    ├── .env
    └── storage
```

The deployment framework itself lives separately:

```text
/opt/laravel-zero-downtime
├── common.sh
├── config.example.sh
├── config.sh
├── deploy.sh
├── permissions.sh
├── rollback.sh
└── setup.sh
```

## Requirements

- Linux server
- Bash 4+
- PHP CLI
- ACL utilities (`setfacl`, `getfacl`)
- Configured web server
- Application owner user
- Runtime user
- SSH access

## Installation

Clone the repository.

```bash
git clone https://github.com/masterei/laravel-zero-downtime.git

cd laravel-zero-downtime
```

Create your deployment configuration.

```bash
cp config.example.sh config.sh
```

Edit `config.sh` to match your server environment.

| Variable           | Description                                                                              | Default    |
| ------------------ | ---------------------------------------------------------------------------------------- | ---------- |
| `APP_OWNER`        | Linux user that owns the application files and executes deployments.                     | `deploy`   |
| `RUNTIME_USER`     | Linux user used by your web server to execute the application (for example, `www-data`). | `www-data` |
| `RELEASES_TO_KEEP` | Number of recent releases to retain on the server.                                       | `5`        |

> **Note:** `APP_NAME` is provided when running `setup.sh`, `permissions.sh`, `deploy.sh`, and `rollback.sh`. The framework derives all application paths automatically from this value.

## Initial Server Setup

Before running the setup script, edit `config.sh` to match your server environment.

```bash
APP_OWNER="deploy"
```

> **Note:**
>
> `APP_OWNER` is the Linux user that owns the application files and executes deployments.
> This is **not** the web server runtime user (for example, `www-data`).
>
> A common configuration is:
>
> - **Application owner:** `deploy`
> - **Runtime user:** `www-data`
>
> The application owner performs deployments, while the runtime user is used by the web server to execute the application.

Initialize the application directory.

```bash
sudo ./setup.sh <app-name>
```

Example:

```bash
sudo ./setup.sh my-app
```

This command:

- Creates the application directory.
- Creates the release structure.
- Creates the shared directory.
- Creates an empty `.env`.

Populate the shared environment file with your production configuration:

```text
/var/www/<app-name>/shared/.env
```

Populate the shared storage directory with your application's persistent files:

```text
/var/www/<app-name>/shared/storage
```

### Repair and Verify Shared Resource Permissions

After populating the shared resources, repair and verify their permissions before deploying the application.

```bash
sudo ./permissions.sh <app-name>
```

Example:

```bash
sudo ./permissions.sh my-app
```

This command:

- Repairs ownership and permissions for `.env`.
- Repairs ownership, permissions, and ACLs for `shared/storage`.
- Verifies storage ACL inheritance.

> **Note:** This command is safe to run multiple times. It may be used after migrating or restoring shared resources, or whenever shared resource permissions need to be repaired.

## Release Artifact

The deployment artifact should contain the application ready for production.

> **Note:**
>
> - The archive contents must be the application files themselves; do not wrap the application in an additional top-level directory.
> - Shared resources such as `.env` and `storage` are managed separately by the deployment framework and are linked during deployment.
> - The artifact must include Laravel's `bootstrap/cache` directory.

Typical contents:

- Laravel application source
- `vendor/`
- Built frontend assets
- `.deploy/`

The artifact should not include environment-specific files such as:

- `.env`
- `storage/`

## Deploying a Release

Deploy a release artifact.

```bash
./deploy.sh <app-name> <release-name> <artifact-path>
```

Example:

```bash
./deploy.sh \
    my-app \
    20260713153015-a4c9d8e \
    /tmp/my-app-20260713153015-a4c9d8e.tar.gz
```

> **Note:** The new release is activated only after extraction, shared resource linking, and the release hook complete successfully. If the deployment fails before activation, the current release remains active.

## Deployment Workflow

```text
CI/CD
 │
 ├── Build application
 ├── Create artifact
 ├── Upload artifact
 └── Execute deploy.sh
          │
          ▼
Validate
      │
Extract Release
      │
Link Shared Resources
      │
Execute Release Hook
      │
Activate Release
      │
Cleanup
```

## Rolling Back

```bash
./rollback.sh <app-name>
```

The script will:

- List retained releases available for rollback
- Prompt for confirmation
- Atomically switch the active release

## Application Hooks

Each application can provide optional deployment scripts by creating a `.deploy` directory in the project root.

Both scripts are optional. If a script does not exist, it is skipped automatically.

Scripts are executed from the root of the extracted release.

```text
my-app/
├── .deploy
│   ├── release.sh
│   └── rollback.sh
├── app
├── bootstrap
├── config
├── database
├── public
├── resources
├── routes
├── storage
├── vendor
├── artisan
├── composer.json
└── package.json
```

### `.deploy/release.sh`

Executed after shared resources are linked and before the release is activated.

Example:

```bash
#!/usr/bin/env bash

set -Eeuo pipefail

php artisan migrate --force
php artisan optimize
php artisan storage:link
php artisan queue:restart
```

> Release hooks run before the new release is activated. Keep hooks safe to execute as part of a deployment and ensure database migrations are compatible with both the current and new application versions when zero-downtime behavior is required.

### `.deploy/rollback.sh`

Executed before the selected release is activated.

Example:

```bash
#!/usr/bin/env bash

set -Eeuo pipefail

php artisan optimize
php artisan queue:restart
```

## CI/CD Integration

The reference workflow has been tested with **GitHub Actions**.

The framework is designed to work with CI/CD systems capable of:

1. Building the application.
2. Creating a release artifact.
3. Uploading the artifact to the server.
4. Executing `deploy.sh`.

Although the deployment process is CI/CD independent by design, it has only been tested with GitHub Actions. Support for other CI/CD platforms has not yet been verified.

## GitHub Actions

An example GitHub Actions workflow is provided in:

```text
examples/github-actions.yml
```

The workflow demonstrates how to:

1. Build the Laravel application.
2. Install production dependencies.
3. Build frontend assets.
4. Create a release artifact.
5. Upload the artifact to the server.
6. Execute `deploy.sh`.

### Required Secrets

| Secret               | Description                                     |
| -------------------- | ----------------------------------------------- |
| `REMOTE_HOST`        | Server hostname or IP address.                  |
| `REMOTE_USER`        | SSH user used for deployment.                   |
| `SSH_PRIVATE_KEY`    | Private SSH key for authentication.             |
| `REMOTE_FINGERPRINT` | SSH host key fingerprint.                       |
| `SSH_PASSPHRASE`     | Passphrase for the private key (if applicable). |

### Required Environment Variables

| Variable   | Description                                        |
| ---------- | -------------------------------------------------- |
| `APP_NAME` | Application name used by the deployment framework. |

## Scripts

| Script           | Description                                            |
| ---------------- | ------------------------------------------------------ |
| `setup.sh`       | Initializes an application on the server.              |
| `permissions.sh` | Repairs and verifies permissions for shared resources. |
| `deploy.sh`      | Deploys a new application release.                     |
| `rollback.sh`    | Activates a previous release.                          |
| `common.sh`      | Shared utility functions.                              |
| `config.sh`      | Framework configuration.                               |

# Author

**Rei Junior**

GitHub: [@masterei](https://github.com/masterei)

# License

This project is licensed under the MIT License.

See the [`LICENSE`](LICENSE.md) file for details.
