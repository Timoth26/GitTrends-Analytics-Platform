.PHONY: install airflow-up airflow-down airflow-restart dbt-run dbt-debug dbt-test upgrade-pip install-dbt install-pyspark

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
	cd ./dbt/gittrends_dbt && dbt test --select test_type:generic
	
dbt-tests-singular:
	cd ./dbt/gittrends_dbt && dbt test --select test_type:singular

terraform-apply:
	cd ./terraform && terraform apply

upgrade-pip:
	python -m pip install --upgrade pip

install-dbt: upgrade-pip
	pip install dbt-core dbt-athena-community

install-pyspark: upgrade-pip
	pip install -e . pytest pyspark dotenv

install-all: install-dbt install-pyspark

run-tests:
	PYTHONPATH=src pytest tests/ -v