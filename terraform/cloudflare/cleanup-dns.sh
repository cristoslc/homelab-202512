#!/bin/bash
set -e

# Fetch all A records for the DNS name
RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${DNS_NAME}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json")

# Check if API call succeeded
SUCCESS=$(echo "$RECORDS" | jq -r '.success')
if [ "$SUCCESS" != "true" ]; then
  echo "Error fetching DNS records:"
  echo "$RECORDS" | jq
  exit 1
fi

# Delete records that don't match our NEW_IP or don't have the Terraform comment
echo "$RECORDS" | jq -r --arg ip "$NEW_IP" \
  '.result[] | select(.content != $ip or (.comment // "" | contains("managed by Terraform") | not)) | .id' | \
while read -r record_id; do
  if [ -n "$record_id" ]; then
    echo "Deleting duplicate/unmanaged DNS record: $record_id"
    DELETE_RESULT=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/$record_id" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json")

    DELETE_SUCCESS=$(echo "$DELETE_RESULT" | jq -r '.success')
    if [ "$DELETE_SUCCESS" = "true" ]; then
      echo "Successfully deleted record $record_id"
    else
      echo "Failed to delete record $record_id:"
      echo "$DELETE_RESULT" | jq
    fi
  fi
done

echo "DNS cleanup complete"
