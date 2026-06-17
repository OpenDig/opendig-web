# System Overview

OpenDig Web is a Rails application, but not a typical all-ActiveRecord Rails app. The project mixes several storage and configuration sources.

## Main Components

### Rails App

The Rails app handles routing, controller actions, views, authentication hooks, form rendering, and report generation.

Key entry points:

- [config/routes.rb](../config/routes.rb)
- [app/controllers/application_controller.rb](../app/controllers/application_controller.rb)

### CouchDB

CouchDB is the main store for excavation records such as areas, squares, loci, pails, finds, and registrar-related data.

Connection setup is in [config/initializers/couchdb.rb](../config/initializers/couchdb.rb). Local development points at the `db` service defined in [config/couchdb.yml](../config/couchdb.yml).

### MinIO

MinIO acts as S3-compatible object storage in development. The app uses it for uploaded find images and referenced daily photos.

Setup is in [config/initializers/s3_bucket.rb](../config/initializers/s3_bucket.rb).

### imgproxy

imgproxy generates transformed image URLs for items stored in MinIO. This is how the app serves thumbnails and resized images.

### Redis

Redis is available for caching and related runtime support. The app also uses Rails cache around image lookups.

### CSV Data Files

Some report data still comes directly from files in `data/` rather than CouchDB. This is important when investigating report behavior.

## Feature Map

The main routes are:

- `areas` and nested `squares`
- nested `loci`
- nested `pails`
- nested `finds`
- `registrar`
- `bulk_uploads`
- `reports`

See [config/routes.rb](../config/routes.rb) for the exact route map.

## Configuration Sources

The app relies on several non-code configuration files:

- [config/descriptions.json](../config/descriptions.json): form sections, lookups, report metadata, field sets
- [config/views.yaml](../config/views.yaml): CouchDB design doc and view definitions
- [config/couchdb.yml](../config/couchdb.yml): CouchDB connection info
- [.envrc.example](../envrc.example): example environment variables

## Runtime Data Flow

A typical request path looks like this:

1. A controller action reads from CouchDB or a CSV source.
2. The action passes data into an ERB view.
3. Form labels and select options often come from `config/descriptions.json`.
4. Image URLs are derived from MinIO object keys and transformed by imgproxy.

## Important Architectural Notes

- Most domain objects are plain Ruby classes or raw CouchDB docs, not ActiveRecord models.
- The app boots without Active Record or `sqlite3`; persistence is centered on CouchDB via CouchRest plus file-backed data sources.
- Reports are partly file-backed, so production bugs may come from CSV content rather than controller logic alone.
- CouchDB views are auto-synced during app boot, which is unusual if you are coming from a standard Rails + SQL background.
