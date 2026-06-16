.PHONY: install airflow-up airflow-down airflow-restart dbt-run dbt-debug dbt-test install

airflow-up:
	docker compose -f ./airflow/docker-compose.yml up -d

airflow-down:
	docker compose -f ./airflow/docker-compose.yml down

airflow-restart:
	docker compose -f ./airflow/docker-compose.yml restart

dbt-run:
	cd ./dbt/gittrends_dbt && dbt run

dbt-debug:
	cd ./dbt/gittrends_dbt && dbt debug

dbt-test:
	cd ./dbt/gittrends_dbt && dbt test

terraform-apply:
	cd ./terraform && terraform apply

install:
	pip install --upgrade pip
	pip install dbt-core dbt-athena-community