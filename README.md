This is a wordpress app in docker

To take advantage of concurrency runs of docker compose, we need to export two environment variables. Do that by running the commands below:
    For Windows Command Prompt:
    set DOCKER_BUILDKIT=1
    set COMPOSE_DOCKER_CLI_BUILD=1

In the directory containing docker-compose.yml, Run the command below to create the docker container
    docker-compose up

Since we're not using a PEM file, we need to use an instance profile that will enable access via session manager.
This allows us to connect to the EC2 instance using session manager. 
Refer to https://korniichuk.medium.com/session-manager-e724eb105eb7 on how to Create AWS IAM Role.