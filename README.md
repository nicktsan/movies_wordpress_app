To take advantage of concurrency runs of docker compose, we need to export two environment variables. Do that by running the commands below:
    For Windows Command Prompt:
    set DOCKER_BUILDKIT=1
    set COMPOSE_DOCKER_CLI_BUILD=1

In the directory containing docker-compose.yml, Run the command below to create the docker container
    docker-compose up