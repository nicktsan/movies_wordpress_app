This is a wordpress app in docker

To take advantage of concurrency runs of docker compose, we need to export two environment variables. Do that by running the commands below:
    For Windows Command Prompt:
    setx DOCKER_BUILDKIT=1
    setx COMPOSE_DOCKER_CLI_BUILD=1

In the directory containing docker-compose.yml, Run the command below to create the docker container
    docker-compose up

Since we're not using a PEM file, we need to use an instance profile that will enable access via session manager.
This allows us to connect to the EC2 instance using session manager. 
Refer to https://korniichuk.medium.com/session-manager-e724eb105eb7 on how to Create AWS IAM Role.

8:41 https://www.youtube.com/watch?v=8_QSES_P67s
5:13 for iamprofile without pem file

//TODO: define vpc_id and region in input.tfvars and backend.tf