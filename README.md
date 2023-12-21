# DevOps Assessment

This solution contains following folder structure:

- solution
  - app (application)
  - aws (Terraform IaC for AWS deployment)
  - helm (helm chart template)
  - test (test artifact)

### Prerequisites for running solution code

 * make (https://www.gnu.org/software/make/)
 * local docker daemon
 * buildpack (https://buildpacks.io)
 * terraform
 * k3d (https://k3d.io)
 * helm
 * AWS cli (and valid credential session)
 * Lens K8s IDE (https://k8slens.dev)


# Non-prod local infrastructure setup

This script will provide a k3d based local kubernetes infrastructure, and then, on top of it, the test environment for the base application.

run:
```sh
make deploy-non-prod

```

app is responding in http://localhost:8080/posts


## load app tests

In order to simulate a hpa and general perception of cpu and memory application consuption: 

run:
```sh
make load-test:

```

hpa should be followed using :
```sh
kubectl get hpa -w
kubectl top po -n apps-non-prod 

```

Increasing load: 
```sh
kubectl scale deployment/load-test --replicas 5

```

# prod AWS infrastructure setup

With an assumption that we have a new, empty AWS account, this section will to provision some base infrastructure just one time.
These steps will provision:
 * a minimal VPC us-east-1 with 3 subnets
 * ECR repositories for docker images
 * EKS Karpenter Cluster

In this section will must use your aws credential:
```sh
source aws_session
```
Now run:
```sh
make deploy-prod

```

## Build/push dockerhub image

If you need build a new application image: It will be pushed in a public dockerhub repo such as geocer/interview-test-main :
```sh
make buildapps
```

## Build/push AWS private registry

If you need build a new application image: It will be pushed in a private AWS ECR registry (make sure you have AWS credential):

```sh
make buildapp-aws AWS_ACCOUNT="111111111" AWS_REGION="us-east-1"
```

## Destroy environments 

To delete the deployment provisioned by terraform or local, run following commands:
```sh
make destroy-non-prod
make destroy-prod

```