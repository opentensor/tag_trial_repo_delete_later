#!/bin/bash

# Initialize variables
script=""
autoRunLoc=$(readlink -f "$0")
proc_name="auto_run_validator" 
args=()


# Check if pm2 is installed
if ! command -v pm2 &> /dev/null
then
    echo "pm2 could not be found. To install see: https://pm2.keymetrics.io/docs/usage/quick-start/"
    exit 1
fi

# Checks if $1 is smaller than $2
# If $1 is smaller than or equal to $2, then true. 
# else false.
versionLessThanOrEqual() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

# Checks if $1 is smaller than $2
# If $1 is smaller than $2, then true. 
# else false.
versionLessThan() {
    [ "$1" = "$2" ] && return 1 || versionLessThanOrEqual $1 $2
}


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
    # Fetch the latest tags (if any) from the repository
    git fetch --all

    # Pull latest changes
    git pull origin $branch

    latest_tag=$(git describe --tags `git rev-list --tags --max-count=1`)

    echo "current validator tag:" "$current_tag" 
    echo "latest validator tag:" "$latest_tag" 

    # If the file has been updated
    if versionLessThan $current_tag $latest_tag; then
        # latest_tag is newer than current_tag, should download and reinstall.
        echo "New tag published. Updating the local copy."
        
        # Pull latest changes
        git checkout -b $latest_tag $latest_tag

        # Install latest changes just in case.
        #pip install -e ../

        # Update the current tag 
        # current_tag=$(git describe --tags --abbrev=0)
        # # Check if script is already running with pm2
        # if pm2 status | grep -q $proc_name; then
        #     echo "The script is already running with pm2. Stopping and restarting..."
        #     pm2 delete $proc_name
        # fi

        # # Run the Python script with the arguments using pm2
        # echo "Running $script with the following arguments with pm2:"
        # echo "${args[@]}"
        # pm2 start "$script" --name $proc_name --interpreter python3 -- "${args[@]}"
        current_tag=$(git describe --tags --abbrev=0)
        exec "$autoRunLoc $@"
        echo ""
    else
        # current tag is newer than the latest on git. This is likely a local copy, so do nothing. 
        echo "**Will not update**"
        echo "$current_tag is up to date with latest tag $latest_tag."
    fi

    # Wait for a while before the next check
    sleep 5
done
