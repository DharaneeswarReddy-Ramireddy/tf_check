variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.200.0.0/16"
}

variable "private_vpc_cidr" {
  description = "CIDR block for the private VPC"
  type        = string
  default     = "10.201.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet in the main VPC"
  type        = string
  default     = "10.200.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet in the private VPC"
  type        = string
  default     = "10.201.1.0/24"
}

variable "availability_zone_2" {
  description = "Availability zone for the private subnet in the private VPC"
  type        = string
  default     = "us-west-2b"
}

variable "peer_owner_id" {
  description = "AWS account ID for VPC peering connection"
  type        = string
  default     = "866934333672" # Replace with your AWS Account ID
}

variable "allowed_ports" {
  description = "Ports allowed for ingress in the security group"
  type        = list(number)
  default     = [22, 80, 8080]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "networking"
  }
}
