.PHONY: init plan bootstrap up down

AWS_REGION := $(shell aws configure get region)


init:
	terraform -chdir=infra init

plan:
	terraform -chdir=infra plan -var "user=${USER}" -var "aws_region=${AWS_REGION}"

bootstrap:
	-terraform -chdir=infra apply -auto-approve -var "user=${USER}" -var "aws_region=${AWS_REGION}"

infra/lambda_function_payload.zip: $(wildcard infra/lambda/*)
	zip -j -r $@ infra/lambda/*

up: infra/lambda_function_payload.zip bootstrap

down:
	terraform -chdir=infra destroy -auto-approve -var "user=${USER}" -var "aws_region=${AWS_REGION}"
	rm -rf infra/lambda_function_payload.zip
