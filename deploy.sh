#!/bin/bash

# Load generic environment variables
source .env

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --env) ENVIRONMENT="$2"; shift ;; # Shift past the value
        --contract) CONTRACT_TYPE="$2"; shift ;; # Shift past the value
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift # Shift past the current key or value
done

# Path to the environment file
ENV_FILE=".env.$ENVIRONMENT"

# Check if the environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Environment file $ENV_FILE does not exist."
    exit 1
fi

# Source environment variables
source $ENV_FILE

# Echo back the environment for verification
echo "Deploying to $ENVIRONMENT environment with settings from '$ENV_FILE'..."

# Deployment-related commands
echo "Running deployment tasks..."

# Clean the build directory
forge clean

# Determine which contract to deploy
if [ "$CONTRACT_TYPE" = "token" ]; then
    SCRIPT="script/Token.s.sol:DeployToken"
    CONTRACT_NAME="Token"
else
    echo "Invalid contract type. Use 'token'"
    exit 1
fi

echo "Deploying $CONTRACT_NAME..."

# Deploy the selected contract
forge script $SCRIPT \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    -vvvvv \
    --verify \
    --verifier etherscan \
    --verifier-url $VERIFIER_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY