# Troubleshooting

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