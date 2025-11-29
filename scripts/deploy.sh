#!/bin/bash
set -e

# Environment variables passed from GitHub Actions
# PROJECT_NAME, IMAGE_NAME, NGINX_CONFIG_PATH
# DOCKER_USERNAME, DOCKER_PASSWORD

# 1. Check for required environment variables
if [ -z "$BLUE_PORT" ] || [ -z "$GREEN_PORT" ]; then
  echo "Error: BLUE_PORT and GREEN_PORT environment variables must be set."
  exit 1
fi

# 2. Determine the next environment

echo "--- Determining next environment ---"
if sudo docker ps --format '{{.Ports}}' | grep -q ":$BLUE_PORT->"; then
  NEXT_ENV="green"
  NEXT_PORT="$GREEN_PORT"
  CURRENT_PORT="$BLUE_PORT"
else
  NEXT_ENV="blue"
  NEXT_PORT="$BLUE_PORT"
  CURRENT_PORT="$GREEN_PORT"
fi
echo "Next environment is $NEXT_ENV on port $NEXT_PORT"

# 2. Deploy new container
CONTAINER_NAME="${PROJECT_NAME}-${NEXT_ENV}"
echo "Deploying $IMAGE_NAME to $CONTAINER_NAME"

echo "Logging into Docker Hub..."
echo "$DOCKER_PASSWORD" | sudo docker login -u "$DOCKER_USERNAME" --password-stdin

echo "Pulling latest image..."
sudo docker pull "$IMAGE_NAME"

# Check and create network if it does not exist
if ! sudo docker network ls | grep -q 'backend-network'; then
  echo "Creating docker network 'backend-network'..."
  sudo docker network create backend-network
fi

if [ -n "$(sudo docker ps -aq --filter name="$CONTAINER_NAME")" ]; then
  echo "Found existing container (running or stopped). Removing it: $CONTAINER_NAME"
  sudo docker rm -f "$CONTAINER_NAME"
fi

echo "Starting new container..."

if [ -z "$ENV_FILE_CONTENT" ]; then
  echo "ENV_FILE_CONTENT is empty. Running container without .env file."
  sudo docker run -d --name "$CONTAINER_NAME" -p "$NEXT_PORT:$CONTAINER_PORT" --network backend-network --restart=always "$IMAGE_NAME"
else
  echo "ENV_FILE_CONTENT found. Creating temporary .env file."
  # Create a temporary .env file
  ENV_FILE_PATH="/tmp/${CONTAINER_NAME}.env"
  echo "$ENV_FILE_CONTENT" | sudo tee "$ENV_FILE_PATH" > /dev/null

  echo "--- Start of .env file content ---"
  sudo cat "$ENV_FILE_PATH"
  echo "--- End of .env file content ---"

  sudo docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$NEXT_PORT:$CONTAINER_PORT" \
    --network backend-network \
    --env-file "$ENV_FILE_PATH" \
    --restart=always \
    "$IMAGE_NAME"

  # Clean up the temporary .env file
  echo "Removing temporary env file"
  sudo rm "$ENV_FILE_PATH"
fi

# 3. Health Check
echo "Waiting for container to become healthy..."
for i in {1..20}; do
  if curl -sf "http://127.0.0.1:$NEXT_PORT/"; then
    echo "Container is healthy!"
    break
  fi
  echo "Attempt $i/20 failed. Retrying in 5 seconds..."
  sleep 5
done

if ! curl -sf "http://127.0.0.1:$NEXT_PORT/"; then
  echo "Health check failed. Aborting deployment."
  sudo docker logs "$CONTAINER_NAME"
  exit 1
fi

# 4. Switch Nginx traffic
echo "Switching Nginx traffic to port $NEXT_PORT"

echo "--- Nginx config BEFORE update ---"
sudo cat "$NGINX_CONFIG_PATH"
echo "------------------------------------"

sudo sed -i "s/server 127.0.0.1:[0-9]*/server 127.0.0.1:$NEXT_PORT/" "$NGINX_CONFIG_PATH"

echo "--- Nginx config AFTER update ---"
sudo cat "$NGINX_CONFIG_PATH"
echo "-----------------------------------"

sudo nginx -t
sudo systemctl reload nginx
echo "Traffic switched successfully."

# 5. Remove old container
OLD_CONTAINER_ID=$(sudo docker ps -q --filter "publish=$CURRENT_PORT")
if [ -n "$OLD_CONTAINER_ID" ]; then
  echo "Stopping and removing old container $OLD_CONTAINER_ID on port $CURRENT_PORT"
  sudo docker rm -f "$OLD_CONTAINER_ID"
else
  echo "No old container found on port $CURRENT_PORT"
fi

echo "Blue-green deployment complete."
