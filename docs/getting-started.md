# Getting Started

This guide is for a first local setup of OpenDig Web.

## Prerequisites

Before getting started, ensure you have the following installed:

- **Docker** (version 20.10 or later)
- **Docker Compose** (version 2.0 or later)
- **direnv** (for environment variable management)
  - Install via Homebrew: `brew install direnv`
  - Or visit: https://direnv.net/docs/installation.html
- **Ruby 3.2.0** (if running locally without Docker)

## 1. Configure Environment Variables

This project uses `direnv` to automatically load environment variables from a `.envrc` file.

### 1. Copy the example environment file

```bash
cp .envrc.example .envrc
```

### 2. Configure your environment variables

Edit the `.envrc` file with your configuration. The file includes:

- **AWS Credentials**: For S3-compatible storage (MinIO in development)
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

- **Authentication**:
  - `EDIT_USER` / `EDIT_PASSWORD`: For edit access
  - `READ_ONLY_USER` / `READ_ONLY_PASSWORD`: For read-only access

- **Image Proxy** (imgproxy):
  - `IMGPROXY_KEY`: 128-character string
  - `IMGPROXY_SALT`: 128-character string
  - `IMGPROXY_URL`: http://imgproxy:8080

AWS credentials for development can be found/updated in the `docker-compose.yml` file.

Generate hex encoded strings using the following example (from https://docs.imgproxy.net/configuration/options)

```bash
echo $(xxd -g 2 -l 64 -p /dev/random | tr -d '\n')
```

- **Rails Environment**:
  - `RAILS_ENV`: Set to `development` for local development

### 3. Building the site

```bash
direnv allow
```

This command tells direnv that it's safe to load the `.envrc` file in this directory. The environment variables will now be automatically loaded whenever you enter this directory.

## 2. Getting Started

### 1. Pre-fill CouchDB database (first-time setup only)

For first-time setup, you need to unzip the initial CouchDB data to pre-fill the database:

```bash
unzip couchdb-data-start-data.zip -d couchdb-data
```

**Note**: This step is only needed once. After the initial setup, the `couchdb-data/` directory will persist your data. If you need to reset the database, you can remove the `couchdb-data/` directory and unzip again.

### 2. Start Docker services

The application uses Docker Compose to run all required services:

- **CouchDB** (database) - Port 5984
- **MinIO** (S3-compatible storage) - Ports 9000 (API), 9001 (Console)
- **imgproxy** (image processing) - Port 8080
- **Redis** (caching) - Port 6379
- **Rails App** - Ports 3000 (web), 3001 (debugger)

Start all services:

```bash
docker compose up -d
```

This will:
- Build the Rails application container
- Start all dependent services (CouchDB, MinIO, imgproxy, Redis)
- Run the Rails application using `bin/dev` (which uses foreman)

## 3. Access the application

```bash
docker compose up -d
```

This starts:

- Rails application `http://localhost:3000`
- MinIO Console on `http://localhost:9001` (admin/password)
- CouchDB on `http://localhost:5984` (admin/password)


## 4. View logs

View logs from all services:

```bash
docker compose logs -f
```
View logs from a specific service:

```bash
docker compose logs -f app

Run tests:

```bash
bin/spec
```

## First Things To Check

After setup, verify:

- the app loads at `http://localhost:3000`

If the app fails at startup, read [Troubleshooting](troubleshooting.md).
