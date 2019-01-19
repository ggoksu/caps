#
# jq -n \
#   --argjson pcf_availability_zones '{}' \
#   --arg network "infrastructure" \
#   "$(cat network_assignment.jq)"
#
{
  "network": {
    "name": $network
  },
  "singleton_availability_zone": {
    "name": ($pcf_availability_zones | .azs | .[0] | .name)
  }
}