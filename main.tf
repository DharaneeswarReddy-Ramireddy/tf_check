/***********************************
 * Pull in Availability Zones for Region
 ***********************************/
data "aws_availability_zones" "azs" {
  state = "available"
}

output "availability_zone" {
  value = element(data.aws_availability_zones.azs.names, 0)
}

/***********************************
 * Main VPC (dharan_inventory_vpc)
 ***********************************/
resource "aws_vpc" "dharan_inventory_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    {
      Name = "dharan_inventory_vpc"
    },
    var.tags
  )
}

/***********************************
 * Internet Gateway for Main VPC
 ***********************************/
resource "aws_internet_gateway" "dharan_inventory_igw" {
  vpc_id = aws_vpc.dharan_inventory_vpc.id
  tags = merge(
    {
      Name = "dharan_inventory_igw"
    },
    var.tags
  )
}

/***********************************
 * Public Subnet in Main VPC
 ***********************************/
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.dharan_inventory_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  map_public_ip_on_launch = true
  tags = merge(
    {
      Name = "public_subnet"
    },
    var.tags
  )
}

/***********************************
 * Route Table for Internet Gateway in Main VPC
 ***********************************/
resource "aws_route_table" "dharan_inventory_vpc_rt" {
  vpc_id = aws_vpc.dharan_inventory_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dharan_inventory_igw.id
  }
  tags = merge(
    {
      Name = "dharan_inventory_vpc_rt"
    },
    var.tags
  )
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.dharan_inventory_vpc_rt.id
}

/***********************************
 * Security Group for Main VPC
 ***********************************/
resource "aws_security_group" "dharan_main_sg" {
  vpc_id = aws_vpc.dharan_inventory_vpc.id

  # Allow ICMP (ping)
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow specified ports from variable
  dynamic "ingress" {
    for_each = var.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "dharan_main_sg"
    },
    var.tags
  )
}

/***********************************
 * Private VPC (dharan_private_vpc)
 ***********************************/
resource "aws_vpc" "dharan_private_vpc" {
  cidr_block           = var.private_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    {
      Name = "dharan_private_vpc"
    },
    var.tags
  )
}

/***********************************
 * Private Subnet in dharan_private_vpc
 ***********************************/
resource "aws_subnet" "dharan_private_subnet" {
  vpc_id            = aws_vpc.dharan_private_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone_2
  map_public_ip_on_launch = false
  tags = merge(
    {
      Name = "dharan_private_subnet"
    },
    var.tags
  )
}

/***********************************
 * Route Table for dharan_private_vpc (private)
 ***********************************/
resource "aws_route_table" "dharan_private_vpc_rt" {
  vpc_id = aws_vpc.dharan_private_vpc.id
  tags = merge(
    {
      Name = "dharan_private_vpc_rt"
    },
    var.tags
  )
}

resource "aws_route_table_association" "dharan_private_rt_association" {
  subnet_id      = aws_subnet.dharan_private_subnet.id
  route_table_id = aws_route_table.dharan_private_vpc_rt.id
}

/***********************************
 * Peering Connection between VPCs
 ***********************************/
resource "aws_vpc_peering_connection" "peering_connection" {
  vpc_id        = aws_vpc.dharan_inventory_vpc.id
  peer_vpc_id   = aws_vpc.dharan_private_vpc.id
  peer_owner_id = var.peer_owner_id
  auto_accept   = true
  tags = merge(
    {
      Name = "dharan_inventory_private_peering"
    },
    var.tags
  )
}

/***********************************
 * Route Tables for VPC Peering
 ***********************************/
resource "aws_route_table" "dharan_inventory_vpc_rt_with_peering" {
  vpc_id = aws_vpc.dharan_inventory_vpc.id
  route {
    cidr_block                = var.private_vpc_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.peering_connection.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dharan_inventory_igw.id
  }
  tags = merge(
    {
      Name = "dharan_inventory_vpc_rt_with_peering"
    },
    var.tags
  )
}

resource "aws_route_table_association" "public_rt_association_peering" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.dharan_inventory_vpc_rt_with_peering.id
}

resource "aws_route" "dharan_private_vpc_rt_peering" {
  route_table_id             = aws_route_table.dharan_private_vpc_rt.id
  destination_cidr_block     = var.vpc_cidr
  vpc_peering_connection_id  = aws_vpc_peering_connection.peering_connection.id
}

/***********************************
 * Network ACL (NACL) for dharan_inventory_vpc
 ***********************************/
resource "aws_network_acl" "dharan_inventory_nacl" {
  vpc_id = aws_vpc.dharan_inventory_vpc.id
  tags = merge(
    {
      Name = "dharan_inventory_nacl"
    },
    var.tags
  )
}

# Ingress rule for SSH (22)
resource "aws_network_acl_rule" "ssh_inbound" {
  network_acl_id = aws_network_acl.dharan_inventory_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

# Ingress rule for HTTP (8080)
resource "aws_network_acl_rule" "http_inbound" {
  network_acl_id = aws_network_acl.dharan_inventory_nacl.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 8080
  to_port        = 8080
}

# Ingress rule for ICMP (ping)
resource "aws_network_acl_rule" "icmp_inbound" {
  network_acl_id = aws_network_acl.dharan_inventory_nacl.id
  rule_number    = 120
  protocol       = "icmp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 8
  to_port        = 0
}

# Egress rule for all return traffic
resource "aws_network_acl_rule" "return_traffic" {
  network_acl_id = aws_network_acl.dharan_inventory_nacl.id
  rule_number    = 200
  protocol       = "-1"
  rule_action    = "allow"
  egress         = true
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}
