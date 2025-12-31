#!/bin/bash
CF_API_TOKEN=$(grep cloudflare_api_token terraform.tfvars | cut -d'"' -f2)
CF_ZONE_ID=$(grep cloudflare_zone_id terraform.tfvars | cut -d'"' -f2)

echo "Testing API with zone ID: $CF_ZONE_ID"
echo ""
echo "Test 1: List ALL DNS records (no filter)"
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" | jq '.success, .errors'

echo ""
echo "Test 2: List plex A records with filter"
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=plex.theblueroost.me" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" | jq
