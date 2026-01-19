# OpenDig Web

A Rails 7 application for managing archaeological dig data. [Join the Discord!](https://discord.gg/DJ7BZcQMsb)

## Requirements

Before getting started, ensure you have the following installed:

- **Docker** (version 20.10 or later)
- **Docker Compose** (version 2.0 or later)
- **direnv** (for environment variable management)
  - Install via Homebrew: `brew install direnv`
  - Or visit: https://direnv.net/docs/installation.html
- **Ruby 3.2.0** (if running locally without Docker)

## Environment Setup

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

### 3. Allow direnv to load the file

```bash
direnv allow
```

This command tells direnv that it's safe to load the `.envrc` file in this directory. The environment variables will now be automatically loaded whenever you enter this directory.

## Getting Started

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

### 3. Access the application

Once the containers are running, you can access:

- **Rails Application**: http://localhost:3000
- **MinIO Console**: http://localhost:9001 (admin/password)
- **CouchDB**: http://localhost:5984 (admin/password)

### 4. View logs

To see logs from all services:

```bash
docker compose logs -f
```

To see logs from a specific service:

```bash
docker compose logs -f app
```

## Development Workflow

### Running the application

The application runs via Docker Compose using the `bin/dev` script, which uses `foreman` to manage multiple processes:

- **Web server**: Rails server on port 3000 with debugger on port 3001
- **CSS watcher**: Tailwind CSS file watcher

### Stopping services

```bash
docker compose down
```

### Running commands in the container

Execute Rails commands inside the container:

```bash
docker compose exec app bundle exec rails <command>
```

For example:

```bash
docker compose exec app bundle exec rails console
docker compose exec app bundle exec rails db:migrate
```

### Running tests

```bash
bin/spec
```

## Project Structure

- `app/` - Rails application code
- `config/` - Configuration files
- `db/` - SQLite database (development)
- `couchdb-data/` - CouchDB data directory (mounted as volume)
- `minio-data/` - MinIO storage data (mounted as volume)
- `docker-compose.yml` - Docker services configuration
- `.envrc` - Environment variables (not committed to git)

## Services Overview

### CouchDB
- **Purpose**: Document database
- **Port**: 5984
- **Credentials**: admin/password (development)
- **Data**: Persisted in `./couchdb-data/`

### MinIO
- **Purpose**: S3-compatible object storage
- **Ports**: 9000 (API), 9001 (Console)
- **Credentials**: admin/password (development)
- **Data**: Persisted in `./minio-data/`

### imgproxy
- **Purpose**: Image processing and optimization
- **Port**: 8080
- **Note**: Configured to use MinIO as S3 backend

### Redis
- **Purpose**: Caching and session storage
- **Port**: 6379

## Troubleshooting

### direnv not loading

If direnv isn't loading your `.envrc` file:

1. Make sure direnv is installed: `which direnv`
2. Ensure your shell hook is configured (see direnv installation docs)
3. Run `direnv allow` in the project directory
4. If using a new terminal, make sure you're in the project directory

### Port conflicts

If you get port already in use errors, you can:

1. Stop conflicting services
2. Modify port mappings in `docker-compose.yml`
3. Check what's using the port: `lsof -i :3000` (macOS/Linux)

### Container rebuild

If you need to rebuild the application container:

```bash
docker compose build app
docker compose up -d
```

### Database issues

If you need to reset CouchDB data:

```bash
docker compose down
rm -rf couchdb-data
unzip couchdb-data-start-data.zip -d couchdb-data
docker compose up -d
```

**Warning**: This will delete all data in CouchDB. The `docker compose down -v` command will also delete MinIO data.

### Folder permissions issues

If you see permission denied errors in the logs, you may need to setup and run the app in a fresh environment, such as a VM.

At this time, Ubuntu and WSL2 should not have this issue.

## Additional Resources

- Rails documentation: https://guides.rubyonrails.org/
- Docker Compose documentation: https://docs.docker.com/compose/
- direnv documentation: https://direnv.net/docs/
