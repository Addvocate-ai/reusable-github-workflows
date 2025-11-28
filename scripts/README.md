# Reusable Deployment Scripts

This directory contains reusable shell scripts designed to be used in GitHub Actions workflows for deployment.

## `deploy.sh`

This script performs an automated blue-green deployment for a Dockerized application. It ensures zero-downtime releases by deploying a new version to an inactive environment, running a health check, and then switching live traffic.

### How it Works

The script executes the following steps:

1.  **Determine Next Environment**: It checks which environment ("blue" or "green") is currently active by inspecting running Docker containers and their ports. The inactive environment becomes the target for the new deployment.
2.  **Deploy New Container**: It logs into Docker Hub, pulls the specified Docker image, and starts a new container for the target environment. It can optionally create and use a temporary `.env` file for the container.
3.  **Health Check**: It waits for the new container to become healthy by repeatedly sending an HTTP request to its root path (`/`). If the health check fails after several attempts, the script aborts and shows the container logs.
4.  **Switch Nginx Traffic**: Upon a successful health check, it modifies the Nginx site configuration file to route traffic to the new container's port.
5.  **Reload Nginx**: It validates the Nginx configuration and reloads the service to apply the changes, effectively switching live traffic.
6.  **Clean Up**: It stops and removes the old container that was previously serving traffic.

### Usage

This script is intended to be downloaded and executed on a remote server via SSH in a GitHub Actions workflow. It requires several environment variables to be set.

**Example from a GitHub Actions workflow:**

```yaml
- name: Deploy
  uses: appleboy/ssh-action@master
  with:
    host: ${{ env.VPS_HOST }}
    username: ${{ env.VPS_USERNAME }}
    password: ${{ env.VPS_PASSWORD }}
    script: |
      export PROJECT_NAME='my-app'
      export IMAGE_NAME='dockeruser/my-app:latest'
      export NGINX_CONFIG_PATH='/etc/nginx/sites-enabled/my-app.conf'
      export DOCKER_USERNAME='${{ secrets.DOCKER_USERNAME }}'
      export DOCKER_PASSWORD='${{ secrets.DOCKER_PASSWORD }}'
      export BLUE_PORT='8080'
      export GREEN_PORT='8081'
      export CONTAINER_PORT='3000'
      export ENV_FILE_CONTENT='${{ env.ENV_FILE_CONTENT }}'

      curl -o deploy.sh https://raw.githubusercontent.com/Addvocate-ai/reusable-github-workflows/main/scripts/deploy.sh
      chmod +x deploy.sh
      ./deploy.sh
```

### Environment Variables

The script relies on the following environment variables:

| Variable              | Required | Description                                                                                             |
| --------------------- | :------: | ------------------------------------------------------------------------------------------------------- |
| `PROJECT_NAME`        |   Yes    | A unique name for the project, used for naming Docker containers (e.g., `my-app-blue`).                 |
| `IMAGE_NAME`          |   Yes    | The full name of the Docker image to deploy (e.g., `username/repository:tag`).                          |
| `NGINX_CONFIG_PATH`   |   Yes    | The absolute path to the Nginx site configuration file on the server that will be modified.             |
| `DOCKER_USERNAME`     |   Yes    | Your Docker Hub username.                                                                               |
| `DOCKER_PASSWORD`     |   Yes    | Your Docker Hub password or access token.                                                               |
| `BLUE_PORT`           |   Yes    | The host port assigned to the "blue" environment.                                                       |
| `GREEN_PORT`          |   Yes    | The host port assigned to the "green" environment.                                                      |
| `CONTAINER_PORT`      |   Yes    | The port the application listens on *inside* the Docker container (e.g., `80`, `3000`).                 |
| `ENV_FILE_CONTENT`    |    No    | Optional. If provided, its content will be written to a temporary `.env` file for the new container.    |
