#!/usr/bin/env make

include makefile.env
export

pwd := $(shell pwd)

postgres-initdb:
	@echo "======================================="
	@echo "Initializing the database of PostgreSQL"
	@echo "======================================="
	@docker run \
		--detach \
		--env-file $(pwd)/postgres.env \
		--name postgres-initdb \
		--rm \
		--volume $(pwd)/postgres-data:/var/lib/postgresql/data \
		--volume $(pwd)/postgres-initdb.d:/docker-entrypoint-initdb.d \
		postgres:10-alpine > /dev/null
	@sleep 8
	@docker logs postgres-initdb
	@docker stop postgres-initdb > /dev/null
	@echo "==========================="
	@echo "The database is initialized"
	@echo "==========================="

airflow-init:
	@docker run \
		--detach \
		--env-file $(pwd)/postgres.env \
		--name dc-airflow-postgres \
		--rm \
		--volume $(pwd)/postgres-data:/var/lib/postgresql/data \
		--volume $(pwd)/postgres-initdb.d:/docker-entrypoint-initdb.d \
		postgres:10-alpine > /dev/null
	@while [ $$(docker inspect --format={{.State.Status}} dc-airflow-postgres) != "running" ]; \
	do \
		sleep 0.5; \
	done
	@echo "==========================="
	@echo "Initializing Apache Airflow"
	@echo "==========================="
	@[ -d $(pwd)/airflow ] || ( mkdir airflow && sudo chown 50000:0 airflow )
	@docker run \
		--env-file $(pwd)/airflow.env \
		--link dc-airflow-postgres \
		--rm \
		--volume $(pwd)/airflow:/opt/airflow \
		ghcr.io/grammy-jiang/airflow:latest \
		db init
	@echo "======================================="
	@echo "Adding the first user to Apache Airflow"
	@echo "======================================="
	@docker run \
		--env-file airflow.env \
		--link dc-airflow-postgres \
		--rm \
		--volume $(pwd)/airflow:/opt/airflow \
		ghcr.io/grammy-jiang/airflow:latest \
		users create \
		--email $$airflow_email \
		--firstname $$airflow_firstname \
		--lastname $$airflow_lastname \
		--password $$airflow_password \
		--role $$airflow_role \
		--username $$airflow_username
	@docker stop dc-airflow-postgres > /dev/null

