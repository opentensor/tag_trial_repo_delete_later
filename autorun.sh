#!/bin/bash

# Initialize variables
script=""
proc_name="auto_run_validator" 
args=()

# Check if pm2 is installed
if ! command -v pm2 &> /dev/null
then
    echo "pm2 could not be found. To install see: https://pm2.keymetrics.io/docs/usage/quick-start/"
    exit 1
fi

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --script) script="$2"; shift ;;
        --name) name="$2"; shift ;;
        --*) args+=("$1=$2"); shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if script argument was provided
if [[ -z "$script" ]]; then
    echo "The --script argument is required."
    exit 1
fi

branch=$(git branch --show-current)            # get current branch.
echo watching branch: $branch
echo pm2 process name: $proc_name

# Get the current tag locally.
current_tag=$(git describe --tags --abbrev=0)

# Check if script is already running with pm2
if pm2 status | grep -q $proc_name; then
    echo "The script is already running with pm2. Stopping and restarting..."
    pm2 delete $proc_name
fi

# Run the Python script with the arguments using pm2
echo "Running $script with the following arguments with pm2:"
echo "${args[@]}"
pm2 start "$script" --name $proc_name --interpreter python3 -- "${args[@]}"

while true; do
    # Fetch the latest changes from the repository
    git fetch origin $branch
    git pull origin $branch

    latest_tag=$(git describe --tags --abbrev=0)

    echo "current validator tag:" "$current_tag" 
    echo "latest validator tag:" "$latest_tag" 

    # If the file has been updated
    if [ $(printf "%s\n" "$latest_tag" "$current_tag" | sort -V -r | head -1) = $"latest_tag" ]; then
        if [ "$latest_tag" = "$current_tag" ]; then
            # tags are the same, no change.
            echo ""
        else
            # latest_tag is newer than current_tag, should download and reinstall.
            echo "New tag published. Updating the local copy."
            
            # Pull latest changes
            git pull origin $branch

            # Install latest changes just in case.
            pip install -e ../

            # Update the current tag 
            current_tag=$(git describe --tags --abbrev=0)
            # Check if script is already running with pm2
            if pm2 status | grep -q $proc_name; then
                echo "The script is already running with pm2. Stopping and restarting..."
                pm2 delete $proc_name
            fi

            # Run the Python script with the arguments using pm2
            echo "Running $script with the following arguments with pm2:"
            echo "${args[@]}"
            pm2 start "$script" --name $proc_name --interpreter python3 -- "${args[@]}"

            echo ""
        fi
    else
        # current tag is newer than the latest on git. This is likely a local copy, so do nothing. 
        echo "Current tag is newer than the git copy. Will not update."
    fi

    # Wait for a while before the next check
    sleep 5
done