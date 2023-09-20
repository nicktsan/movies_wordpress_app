This project launches a wordpress website within an EC2 instance with Aurora SQL inside of an S3 bucket, using Cloudflare to proxy requests to the vm. The site itself is built within a docker container in the EC2 instance.

Prerequisites:
- Docker and docker-compose
- AWS Account
- Cloudflare account and registered website domain
- S3 bucket

To take advantage of concurrency runs of docker compose, we need to export two environment variables. Do that by running the commands below:
    For Windows Command Prompt:
    setx DOCKER_BUILDKIT=1
    setx COMPOSE_DOCKER_CLI_BUILD=1
    For Windows powershell:
    $env:DOCKER_BUILDKIT=1
    $env:COMPOSE_DOCKER_CLI_BUILD=1

In the directory containing docker-compose.yml, Run the command below to create the docker container
    docker-compose up

Then navigate to the workpress directory

Then, run
terraform init

Set TF_WORKSPACE environment variable to prod.
    For Windows Command Prompt:
    setx TF_WORKSPACE=prod
    For Windows powershell:
    $env:TF_WORKSPACE=prod

Then create a new workspace for prod with:
terraform workspace new prod

Once the new workspace has been created, rerun
terraform init

Then run: 
terraform plan -out out.tfplan
This will save the output of the plan to a file and create the workspace in your Terraform organization.
Alternatively, if you want to use an input file to avoid manually inputting values for database_name, database_master_username, vpc_id, and region, run:
terraform plan -var-file input.tfvars -out out.tfplan
where input.tfvars contains values for database_name, database_master_username, vpc_id, and region.

After planning is finished, create the aws infrastructure with
terraform apply out.tfplan

Check if you can access the EC2 instance via session manager.
sudo su - ubuntu
Check if you can access docker within the EC2 instance:
docker container ls

If the docker containers are created, the wordpress site should be accessible through the public ip, public dns, or <endpoint>.<domain>.

When accessing the site through <endpoint>.<domain>, check if the connection is secure through Cloudflare.
