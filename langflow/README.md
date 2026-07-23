# Langflow Docker Setup

This directory contains a `docker-compose.yml` configuration to easily run [Langflow](https://github.com/langflow-ai/langflow) alongside a PostgreSQL database using Docker.

## Components

* **Langflow**: The main application running on port `7860`.
* **PostgreSQL**: The database used by Langflow to store its data, running on port `5432`.

## Prerequisites

* Docker
* Docker Compose

## Usage

1. **Start the services:**
   Run the following command to start both Langflow and the PostgreSQL database in the background:
   ```bash
   docker-compose up -d
   ```

2. **Access Langflow:**
   Once the containers are up and running, open your web browser and navigate to:
   ```
   http://localhost:7860
   ```

3. **Stop the services:**
   To stop the containers and remove the network, run:
   ```bash
   docker-compose down
   ```

## Configuration

* **Environment Variables**: The `docker-compose.yml` file includes essential environment variables (like `LANGFLOW_DATABASE_URL` and `LANGFLOW_SECRET_KEY`). You may want to update the `LANGFLOW_SECRET_KEY` for better security in a production-like environment.
* **Data Persistence**: Data is persisted using Docker volumes:
  * `./langflow-data` on your host machine maps to Langflow's data directory.
  * `langflow-postgres` (a Docker-managed volume) is used for the database.
