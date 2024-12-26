# The fixed inbound dns IPs for name resolution from SE1
# These are added in some dns forwarded configuration in SE1
output "cidr_blocks" {
  value = {
    "lon" = {
      "sandbox" = {
        "dev" = "10.130.0.0/21"
      }
    }
  }
}
