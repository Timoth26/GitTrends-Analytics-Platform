
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

terraform-apply:
	cd ./terraform && terraform apply