#!/bin/bash

# Check if output_file and log_file were provided
if [ $# -lt 1 ]; then
  echo "Usage: $0 output_file"
  exit 1
fi

# Output file
output_file=$1
# Keyword
keyword=$2
# Log file
log_file="${output_file%.*}-log.txt"

echo "output_file -> $output_file"
echo "log_file -> $log_file"

# Write the header to the output file
echo "Pod,Namespace,Container,Environment Variables" > $output_file

# Get a list of all namespaces
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

# Count the total number of namespaces
total_ns=$(echo $namespaces | wc -w)

# Initialize a counter for the current namespace
current_ns=0

for ns in $namespaces; do
  # Increment the current namespace counter
  ((current_ns++))

  # Print the status
  echo "STATUS: Scanning secrets in namespace $ns ($current_ns/$total_ns)"

  # Get a list of all pods in the namespace
  pods=$(kubectl get pods -n $ns -o jsonpath='{.items[*].metadata.name}')

  for pod in $pods; do
    # Get a list of all containers in the pod
    containers=$(kubectl get pods $pod -n $ns -o jsonpath='{.spec.containers[*].name}')

    for container in $containers; do
      # Get the environment variables
      #echo "namespace: $ns | pod: $pod | container: $container"
      #namespace: default | pod: kbank-lineapi-prod-spending-worker-5bcc4469d9-przhb | container: core

        # Execute the command and capture both stdout and stderr
      output=$(kubectl exec -n $ns $pod -c $container -- env 2>&1 | grep $keyword || true)

      # Check if the output contains an error message
      if [[ $output == *"error:"* ]]; then
        # Write the error message to the log file
        echo "Error getting environment variables for $pod in namespace $ns, container $container: $output" >> $log_file
      else
        env_vars=$output

        # Write the data to the output file
        if [ -n "$env_vars" ]; then
          echo "$pod,$ns,$container,$(echo $env_vars | tr '\n' ',')" >> $output_file
          echo "Updated $output_file with environment variables for $pod in namespace $ns, container $container" >> $log_file
        else
          echo "$pod,$ns,$container," >> $output_file
          echo "Updated $output_file with no environment variables for $pod in namespace $ns, container $container" >> $log_file
        fi
      fi
    done
  done
done

echo "SUCCESS: Finished scanning all namespaces"


