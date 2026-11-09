# inadc-odc

A self-contained Open Data Cube (ODC) environment for the Indonesia Data Cube (INADC). It runs PostGIS + ODC locally via Docker Compose so you can add product definitions, index satellite data, and validate the data cube catalogue before it is consumed by the EKS pipelines.

This repository is also the source of truth for the ODC **product definitions** (`products/`, `products.csv`) and **custom metadata types** (`metadata/`) that the Kubernetes/Argo workflows in the cluster pull from.

## Services

| Service | Description | Documentation |
| --- | --- | --- |
| **PostgreSQL + PostGIS** | Database backend storing ODC metadata and spatial indices | [PostgreSQL Docs](https://www.postgresql.org/docs/) |
| **ODC (Open Data Cube)** | Indexing and data management for satellite imagery | [ODC Docs](https://datacube-core.readthedocs.io/) |

## Prerequisites

- **Docker** — see [Docker's installation docs](https://docs.docker.com/get-docker/)
- **Make** — for the Makefile automation

## Quick Start

1. **Clone the repository:**

   ```bash
   git clone https://github.com/piksel-ina/inadc-odc.git
   cd inadc-odc/
   ```

2. **Set up the environment:**

   ```bash
   make setup
   ```

   Creates `.env` from `.env.example` and generates the ODC configuration (`datacube.conf`). Both are starter templates — use as-is or customise before continuing.

3. **Build the ODC image:**

   ```bash
   make build
   ```

4. **Start the services (PostGIS + ODC):**

   ```bash
   make up
   ```

5. **Initialise the database:**

   ```bash
   make init-db
   ```

6. **Add product definitions:**

   ```bash
   make all-products
   ```

   Adds every product definition in `products/` to the ODC index.

7. **Index data (example):**

   ```bash
   make index-s2l2a
   ```

   Indexes Sentinel-2 L2A with default parameters. Override them with variables:

   ```bash
   make index-s2l2a Bbox='115,-10,117,-8' Date='2021-01-01/2021-01-31'
   ```

8. **Stop the environment:**

   ```bash
   make down
   ```

Run `make help` for the full list of commands.

## Products

Product definitions live in `products/*.yaml` and are catalogued in `products.csv`. Current products include Sentinel-2 L2A, Landsat Collection 2 surface reflectance and surface temperature, Sentinel-1 RTC, Sentinel-2 annual geomedian, and flood hazard. Custom metadata types are defined in `metadata/custom_metadata.odc-type.yaml`.

`products.csv` and the metadata type are consumed by the cluster's ODC sync workflows via their raw GitHub URLs, so changes here propagate to the EKS environment.

## Architecture

```
          ┌──────────────┐        ┌──────────────┐
          │  PostgreSQL  │◄───────┤     ODC      │
          │   + PostGIS  │        │  (indexing)  │
          └──────────────┘        └──────────────┘

   Data flow:  STAC / S3 sources → ODC (indexing) → PostGIS
```

## Docker Build (GitHub Actions)

Pushing a Git tag matching `inadc-odc-vYYYYMMDD-HHMM` builds the ODC image and pushes it to the `inadc-odc` AWS ECR repository (see `.github/workflows/build-inadc-odc.yml`).
