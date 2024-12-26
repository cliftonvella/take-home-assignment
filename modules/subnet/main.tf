data "aws_region" "current" {}

data "aws_availability_zones" "zone" {
  state                  = "available"
  all_availability_zones = true

  filter {
    name   = "group-name"
    values = [data.aws_region.current.name]
  }

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Subnets based on the number of AZs required
resource "aws_subnet" "this" {
  count             = var.az_count
  cidr_block        = cidrsubnet(var.vpc.cidr_block, var.cidr_newbits, count.index + var.cidr_offset)
  availability_zone = data.aws_availability_zones.zone.names[count.index]
  vpc_id            = var.vpc.id

  tags = {
    Name = "${var.name}-${data.aws_availability_zones.zone.names[count.index]}"
  }
}

resource "aws_route_table_association" "this" {
  count          = var.route_table_association == {} ? 0 : var.az_count
  subnet_id      = aws_subnet.this[count.index].id
  route_table_id = var.route_table_association.id
}

# Elastic IP for each NAT Gateway - if required
resource "aws_eip" "this" {
  count  = var.nat_required ? var.az_count : 0
  domain = "vpc"

  tags = {
    Name = "${var.name}-${data.aws_availability_zones.zone.names[count.index]}"
  }
}

# NATs for each subnet if required
resource "aws_nat_gateway" "outbound" {
  count         = var.nat_required ? var.az_count : 0
  subnet_id     = aws_subnet.this[count.index].id
  allocation_id = element(aws_eip.this.*.id, count.index)

  tags = {
    Name = "${var.name}-${data.aws_availability_zones.zone.names[count.index]}"
  }
}

# is subnet for a firewall?  In which case a lot more is required
module "firewall" {
  source = "../firewall"
  count  = var.firewall_type == "none" ? 0 : 1

  az_count          = var.az_count
  name              = var.name
  subnets           = aws_subnet.this
  vpc               = var.vpc
  internet_gateway  = var.internet_gateway
  protected_subnets = var.protected_subnets
}

# To internet is there's no firewall
resource "aws_route_table" "to_igw" {
  count  = var.firewall_type == "none" && var.internet_gateway != "" ? 1 : 0
  vpc_id = var.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway.id
  }

  tags = {
    Name = var.name
  }
}

# Route from this subnet to internet
resource "aws_route_table_association" "to_igw" {
  count          = var.firewall_type == "none" && var.internet_gateway != "" ? var.az_count : 0
  subnet_id      = aws_subnet.this[count.index].id
  route_table_id = aws_route_table.to_igw[0].id
}