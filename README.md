# OpenDig Web

OpenDig Web is a Rails 7 application for managing archaeological dig data. It supports field recording concerning areas, squares, loci, pails, finds, registrar work, and image uploads.

[Join the Discord!](https://discord.gg/DJ7BZcQMsb)

## What This App Does

- Browse excavation data by area and square
- Create and edit loci records
- Upload and display find images

## Getting Started

- Please refer to [Getting Started](docs/getting-started.md).

## Documentation

- [Getting Started](docs/getting-started.md)
- [System Overview](docs/system-overview.md)
- [Data Model and Terminology](docs/data-model-and-terminology.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Contributing](docs/CONTRIBUTING.md)
- [Student Contributions](docs/student-contributions.md)

## Project Layout

- `app/` - Rails application code
- `config/` - Configuration files
- `db/` - SQLite database (development)
- `couchdb-data/` - CouchDB data directory (mounted as volume)
- `minio-data/` - MinIO storage data (mounted as volume)
- `docker-compose.yml` - Docker services configuration
- `.envrc` - Environment variables (not committed to git)

## Additional Resources

- Rails documentation: https://guides.rubyonrails.org/
- Docker Compose documentation: https://docs.docker.com/compose/
- direnv documentation: https://direnv.net/docs/