#!/bin/bash
CLOUDFLARE_TOKEN=$(grep cloudflare_api_token terraform.tfvars | cut -d'"' -f2)
ZONE_ID=$(grep cloudflare_zone_id terraform.tfvars | cut -d'"' -f2)

curl -s -X GET "https://api.cloudflare.com/v1/zones/${ZONE_ID}/dns_records?type=A&name=plex.theblueroost.me" \
  -H "Authorization: Bearer ${CLOUDFLARE_TOKEN}" \
  -H "Content-Type: application/json"
