.PHONY: infra-plan infra-apply up down

AWS_REGION := $(shell aws configure get region)


infra-plan:
	terraform -chdir=infra init
	terraform -chdir=infra plan -var "user=${USER}" -var "aws_region=${AWS_REGION}"

infra-apply:
	-terraform -chdir=infra apply -auto-approve -var "user=${USER}" -var "aws_region=${AWS_REGION}"

up: infra-apply

down:
	terraform -chdir=infra destroy -auto-approve -var "user=${USER}" -var "aws_region=${AWS_REGION}"
