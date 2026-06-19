# OpenDig Web

OpenDig Web is a Rails 7 application for managing archaeological dig data. It supports field recording concerning areas, squares, loci, pails, finds, registrar work, and image uploads.

[Join the Discord!](https://discord.gg/DJ7BZcQMsb)

## What This App Does

- Browse excavation data by area and square
- Create and edit loci records
- Upload and display find images

## Getting Started

- Please refer to [Getting Started](docs/getting-started.md).

## Projects & subdomains

Each archaeological project is its own CouchDB database (`<project>_<env>`, e.g.
`balua_production`) and is selected by subdomain: `balua.opendig.org`,
`umayri.opendig.org`. Locally, use [`lvh.me`](http://lvh.me) (it resolves to
`127.0.0.1`, no `/etc/hosts` edits needed):

- `http://balua.lvh.me:3000`
- `http://umayri.lvh.me:3000`

Seed local project databases (requires a running CouchDB):

```sh
bin/rails projects:seed_dev            # replicates the legacy db into balua_* and creates umayri_*
bin/rails projects:list                # list project keys for the current env
bin/rails 'projects:create[mysite]'    # create a new empty project database
```

The apex host (`http://lvh.me:3000`) shows a project chooser.

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