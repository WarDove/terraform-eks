# terraform-infrastructure

Install [terraform](https://www.terraform.io/downloads.html), additional instructions [here](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started).

# Environment

tfvars:
* profile
* github_token - for CodeBuild builds that pull directly from github without CodePipeline. Allows reporting back build status. Requires permissions to create a webhook.

## Setting up a new (AWS) environment

1. Create a directory for the environment (e.g., `env-staging/`)
1. Update the bootstrap script `aws_terraform_bootstrap.sh` to account for the new environment (update the profile, dynamodb_table, s3_bucket_name)
1. Run the boostrap script to make sure the terraform backend is setup for the new environment
1. Create the SecretsManager secrets in the AWS console. We currently need a secret for 'dockerhub' (the values for this can be copied from other environments) and a secret for '[environment name]-secrets'.
1. Go to AWS Console for CodePipeline and create a codestar connection for github manually. Get the ARN and populate the terraform variable.
1. Create the RDS instanace manually and store DB secrets in the secrets manager created above.
    * NOTE: because moving RDS into a VPC after creation might be problematic, it might be better to create the VPC for the environment before creating RDS by using terraform targeting.
1. Create a `main.tf` file in the environment's directory and fill in the variables needed for `env` module and `cicd` module (if using)
1. Create the tfvars file `terraform.tfvars` for the environment and fill in the values for the required vars.
1. Run `terraform init -backend-config="profile=[profile]"` to initialize the modules as well as the terraform backend
1. Run `terraform plan -var-file terraform.tfvars` and `terraform apply -var-file terraform.tfvars` if the plan looks correct.

# Getting started

## Prerequisites
* setup awscli and credentials - `aws configure --profile [profile]`
* user running the stack needs to have appropriate permissions in AWS.

Following resources are expected to be setup in AWS already, and will be expected to be provided as input variables:
* dockerhub login and password in Secrets Manager in the region where stack will be deployed - provide the secret name as input variable
* Github CodeStar connection with appropriate permissions - provide the ARN as input
* A github personal access token with permission to create webhooks & write to repo, this needs to be provided as input variable.

## Bootstrap

__Not needed if backend was already setup__

If creating the stack from scratch (no resources have ever been created), run the bootstrap script to setup the remote s3 backend so that we don't run into the chicken and egg issue. The bootstrap script only needs to be run once per account (unless we eventually need multiple regions).

`./aws_terraform_boostrap.sh`

## Initializing

Run `terraform init -backend-config="profile=[profile]"` to successfully initialize. This is because variables are not allowed in the terraform backend block.

## Running

Variables:
* if running `terraform plan` or `terraform apply`, run with the parameter `-var-file-"../terraform.tfvars"`

# Development

* checkout branch
* make changes
* `terraform init -backend-config="profile=[profile]` - (initial only) downloads and installs the providers defined in the configuration, or if there have been any module changes
* `terraform plan -var-file terraform.tfvars`
* make a pull request
* merge the pull request
* `terraform apply` - terraform will generate a plan and ask you if you want to apply it

`terraform plan` ans `terraform apply` will automatically include variables from file "terraform.tfvars" if it exists

**Formatting**
* `terraform fmt -recursive` - automatically format *.tf files

**Validation**
* `terraform validate`

# Accessing the Environment

The environment is enabled for [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html#ecs-exec-enabling-and-using). Access can be gained to a container by running the following commands (provided your IAM user has appropriate access as well):

`aws ecs describe-tasks --cluster [cluster name] --tasks [task_id] --profile [profile]` - make sure the `managedAgents` section has a `lastStatus` of "RUNNING"

`aws ecs execute-command --cluster [cluster name] --task [task id]  --profile [profile] --interactive --command '/bin/sh'`
