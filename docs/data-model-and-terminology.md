# Data Model and Terminology

This page explains the domain language used throughout OpenDig Web.

## Core Terms

### Area

An excavation area. The root page lists areas, and areas contain squares.

### Square

A square belongs to an area and groups related loci, pails, and finds.

### Locus

A locus is a dig context within a square. In the UI, loci are the main editable excavation records.

Locus codes are typically represented as:

```text
AREA.SQUARE.###
```

Examples:

- `A.1.001`
- `B.14.023`

Relevant files:

- [app/models/locus.rb](../app/models/locus.rb)
- [app/views/loci](../app/views/loci)

### Pail

A pail is nested under a locus and can hold associated finds, dates, readings, pottery notes, and related field data.

### Find

A find is an item associated with a pail. Finds can have field numbers, types, remarks, GIS IDs, and images.

Relevant files:

- [app/models/find.rb](../app/models/find.rb)
- [app/views/finds](../app/views/finds)

### Registrar Entry

The registrar workflow surfaces finds for curation and registration work across seasons and statuses.

Relevant files:

- [app/models/registrar.rb](../app/models/registrar.rb)
- [app/controllers/registrar_controller.rb](../app/controllers/registrar_controller.rb)


## How Data Is Stored

Text.

### CouchDB Documents

Excavation records are primarily CouchDB documents. A single locus document can include nested arrays for:

- `pails`
- `finds` within each pail
- `photos`
- stratigraphy and description fields

### Object Storage

Images live in MinIO using S3-style object keys. Common prefixes include:

- `finds/`
- `daily_photos/`

### CSV Files

Several reports pull from files in `data/`, including:

- `artifacts.csv`
- `objects.csv`
- `samples.csv`
- `bones.csv`

## Practical Mental Model

When debugging a feature, first figure out which storage layer owns the truth:

- missing or wrong excavation record: likely CouchDB
- missing image: likely MinIO or imgproxy
- wrong report row: possibly a CSV file rather than CouchDB

That one distinction saves a lot of time for new students.
