
airflow-up:
	docker compose -f ./airflow/docker-compose.yml up -d

airflow-down:
	docker compose -f ./airflow/docker-compose.yml down

airflow-restart:
	docker compose -f ./airflow/docker-compose.yml restart