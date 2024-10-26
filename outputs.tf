output "main_vpc_id" {
  value = aws_vpc.dharan_inventory_vpc.id
}

output "private_vpc_id" {
  value = aws_vpc.dharan_private_vpc.id
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.peering_connection.id
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.dharan_private_subnet.id
}
