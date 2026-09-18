resource "aws_vpc" "vpc" {
  cidr_block                           = local.vpc_cidr_block
  instance_tenancy                     = "default"
  enable_dns_support                   = true
  enable_dns_hostnames                 = true
  assign_generated_ipv6_cidr_block     = false
  enable_network_address_usage_metrics = false
  tags                                 = { Name = "${local.tag_header}vpc" }
}
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id
  tags                   = { Name = "${local.tag_header}default-rt" }
}
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id
  tags   = { Name = "${local.tag_header}default-sg" }
}

# #################################################################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = { Name = "${local.tag_header}igw" }
}
resource "aws_eip" "eip" {
  count = local.create_nat_gateway ? 1 : 0

  domain = "vpc"
  tags   = { Name = "${local.tag_header}nat-eip" }
}
resource "aws_nat_gateway" "nat" {
  count         = local.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.eip[count.index].id
  subnet_id     = aws_subnet.subnet["public${split("-", local.azs[0])[2]}"].id

  depends_on = [aws_internet_gateway.igw]
  tags       = { Name = "${local.tag_header}nat" }
}

# #################################################################################

resource "aws_subnet" "subnet" {
  for_each          = local.subnet_map
  vpc_id            = aws_vpc.vpc.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  map_public_ip_on_launch                     = each.value.type == "public" ? true : false
  enable_resource_name_dns_a_record_on_launch = true

  tags = merge({
    "Name"        = "${local.tag_header}${each.key}-subnet"
    "Type"        = each.value.type
    "Environment" = "test"
    "ManagedBy"   = "Terraform"
    "RouteTable"  = each.value.rt
    },

    each.value.type == "public" ? { "kubernetes.io/role/elb" = "1" } : {},
    each.value.type == "public" ? { "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared" } : {},

    each.value.type == "cluster" ? { "kubernetes.io/role/internal-elb" = "1" } : {},
    each.value.type == "cluster" ? { "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared" } : {},
  )
}

# #################################################################################

resource "aws_route_table" "route" {
  for_each = merge(local.route_map)
  vpc_id   = aws_vpc.vpc.id
  tags     = { Name = "${local.tag_header}${each.key}-rt" }
}
resource "aws_route_table_association" "route_asso" {
  for_each       = aws_subnet.subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.route[each.value.tags["RouteTable"]].id
}
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.route["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
# 1. NAT Gateway 경로 (count가 0보다 클 때만)
resource "aws_route" "private_nat_gateway_access" {
  for_each = local.create_nat_gateway ? toset([
    for k, v in local.route_map : k if v.type != "public"
  ]) : toset([]) # 0이 아니면 빈 리스트를 반환해 리소스 생성 안 함

  route_table_id         = aws_route_table.route[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}
# 2. NAT Instance 경로 (count가 정확히 0일 때만)
resource "aws_route" "private_nat_instance_access" {
  for_each = !local.create_nat_gateway ? toset([
    for k, v in local.route_map : k if v.type != "public"
  ]) : toset([]) # 0이 아니면 빈 리스트를 반환해 리소스 생성 안 함

  route_table_id         = aws_route_table.route[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance[0].primary_network_interface_id
  depends_on             = [aws_instance.nat_instance]
}

# #################################################################################

resource "aws_instance" "nat_instance" {
  count         = !local.create_nat_gateway ? 1 : 0
  ami           = local.ami_ubuntu_id
  instance_type = "t3.nano"

  subnet_id                   = aws_subnet.subnet["public${split("-", local.azs[0])[2]}"].id
  associate_public_ip_address = true
  source_dest_check           = false

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true # 인스턴스 삭제 시 함께 삭제
  }

  key_name               = var.ssh_key
  vpc_security_group_ids = [aws_security_group.nat_sg.id]

  user_data = file("${path.module}/nat-user-data-ubuntu.sh")
  tags      = { Name = "${local.tag_header}nat-instance" }
}

# #################################################################################

resource "aws_network_acl" "nacl" {
  for_each = toset(local.subnet_type)
  vpc_id   = aws_vpc.vpc.id

  # 인바운드 규칙: 모든 IP에서 HTTP(80), HTTPS(443) 및 임시 포트 허용
  ingress {
    rule_no    = 100         # 👈 원하는 100번 지정
    protocol   = "-1"        # -1은 모든 프로토콜(TCP, UDP, ICMP 등)을 의미합니다.
    action     = "allow"     # 👈 Allow 설정
    cidr_block = "0.0.0.0/0" # 모든 IP 대역
    from_port  = 0
    to_port    = 0
  }
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "${local.tag_header}${each.value}-nacl" }
}
resource "aws_network_acl_association" "nacl_assoc" {
  for_each       = local.subnet_map
  subnet_id      = aws_subnet.subnet[each.key].id
  network_acl_id = aws_network_acl.nacl[each.value.type].id
}
