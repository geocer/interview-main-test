BASE_DIR := $(dir $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
DOCKERHUB = geocer/interview-test-main

#prereq section
DOCKER := $(shell command -v docker 2> /dev/null)
BREW := $(shell command -v brew 2> /dev/null)
BUILDPACK := $(shell command -v pack 2> /dev/null)
HELM := $(shell command -v helm 2> /dev/null)
K3D := $(shell command -v k3d 2> /dev/null)
KUBECTL := $(shell command -v kubectl 2> /dev/null)
AWS-CLI := $(shell command -v aws 2> /dev/null)
TERRAFORM := $(shell command -v terraform 2> /dev/null)

check-prereqs: 
	@echo "Looking for docker installation..."
ifndef DOCKER
	@echo "Please install docker to continue"
endif
	@echo "\t...docker done"
	@echo "Looking for buildpack installation..."
ifndef BUILDPACK
	@echo "Please install buildpack to continue"
endif
	@echo "\t...buildpack done"
	@echo "Looking for helm installation..."
ifndef HELM
	@echo "Please install helm to continue"
endif
	@echo "\t...helm done"
	@echo "Looking for k3d installation..."
ifndef K3D
	@echo "Please install k3d to continue"
endif
	@echo "\t...k3d done"
	@echo "Looking for kubectl installation..."
ifndef KUBECTL
	@echo "Please install kubectl to continue"
endif
	@echo "\t...kubectl done"
	@echo "Looking for aws-cli installation..."
ifndef AWS-CLI
	@echo "Please install aws-cli to continue"
endif
	@echo "\t...aws done"
	@echo "Looking for terraform installation..."
ifndef TERRAFORM
	@echo "Please install terraform to continue"
endif
	@echo "\t...terraform done"

create-k3d-cluster: check-prereqs
	k3d cluster create non-prod-k3d-cluster --servers 3 --api-port 6550 -p "8080:80@loadbalancer" --agents 3

buildapp: check-prereqs
	pack build interview-test-main --path ${BASE_DIR}/app --builder heroku/builder:22
	docker tag interview-test-main:latest ${DOCKERHUB}:latest
	docker push ${DOCKERHUB}:latest

buildapp-aws:
	pack build interview-test-main --path ${BASE_DIR}/app --builder heroku/builder:22
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker tag interview-test-main:latest $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com/interview-test-main:latest
	docker push $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com/interview-test-main:latest

load-test:
	kubectl apply -f ${BASE_DIR}/test/load-test.yaml

deploy-helm-non-prod:
	helm upgrade --install mariadb oci://registry-1.docker.io/bitnamicharts/mariadb --set auth.rootPassword='test' --set auth.password='test' --set auth.username='test' --set auth.database='test' --set auth.forcePassword=true  --recreate-pods -n apps-non-prod --create-namespace
	helm upgrade --install interview-test-main-chart ${BASE_DIR}/helm/infraestructure-interview-test-main --values ${BASE_DIR}/helm/infraestructure-interview-test-main/values-non-prod.yaml --namespace apps-non-prod --create-namespace

deploy-helm-prod:
	helm upgrade --install mariadb oci://registry-1.docker.io/bitnamicharts/mariadb-galera --set auth.rootPassword='test' --set auth.password='test' --set auth.username='test' --set auth.database='test' --set auth.forcePassword=true --recreate-pods -n apps-prod --create-namespace
	helm upgrade --install interview-test-main-chart ${BASE_DIR}/helm/infraestructure-interview-test-main --values ${BASE_DIR}/helm/infraestructure-interview-test-main/values.yaml --namespace apps-prod --create-namespace
	
%.tf-module-apply:
	cd ${BASE_DIR}/aws/$* && rm -rf .terraform && terraform init && terraform apply -auto-approve

%.tf-module-destroy:
	cd ${BASE_DIR}/aws/$* && rm -rf .terraform && terraform init && terraform destroy -auto-approve

ci-prod:
	aws eks update-kubeconfig --region us-east-1 --name ex-karpenter-cluster
	kubectl apply  -f https://github.com/buildpacks-community/kpack/releases/download/v0.11.5/release-0.11.5.yaml

deploy-non-prod: check-prereqs
	$(MAKE) create-k3d-cluster
	$(MAKE) deploy-helm-non-prod

deploy-prod: check-prereqs
	$(MAKE) ecr-private.tf-module-apply
	$(MAKE) karpenter-cluster.tf-module-apply
	$(MAKE) ci-prod
	$(MAKE) deploy-helm

destroy-non-prod: 
	k3d cluster delete non-prod-k3d-cluster

destroy-prod:
	$(MAKE) ecr-private.tf-module-destroy
	$(MAKE) karpenter-cluster.tf-module-destroy