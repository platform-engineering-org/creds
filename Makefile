.PHONY: bootstrap-plan bootstrap zip_files up down

AWS_REGION := $(shell aws configure get region)


bootstrap-plan:
	terraform -chdir=infra init
	terraform -chdir=infra plan -var "user=${USER}" -var "aws_region=${AWS_REGION}"

bootstrap:
	-terraform -chdir=infra apply -auto-approve -var "user=${USER}" -var "aws_region=${AWS_REGION}"

zip_dir:
	mkdir zip_dir

zip_files: zip_dir infra/lambda/ddb-to-opensearch/lambda_function.py infra/lambda/ddb-to-opensearch/requirements.txt
	pip3 install --upgrade --use-feature=2020-resolver --target infra/lambda/ddb-to-opensearch/zip_dir -r infra/lambda/ddb-to-opensearch/requirements.txt
	cp infra/lambda/ddb-to-opensearch/lambda_function.py infra/lambda/ddb-to-opensearch/zip_dir/

up: zip_files bootstrap

down:
	terraform -chdir=infra destroy -auto-approve -var "user=${USER}" -var "aws_region=${AWS_REGION}"
	rm -rf infra/lambda_function_payload.zip
