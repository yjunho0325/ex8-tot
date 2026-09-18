locals {
  common_tags = {
    Environment = var.env_type # prod, dev, test, lab
    Owner       = var.owner
    Class       = "bipa17"
  }

  region        = data.aws_region.current.region
  azs           = data.aws_availability_zones.available_az.names
  ami_linux_id  = data.aws_ami.amazon_linux_2023.id
  ami_ubuntu_id = data.aws_ami.ubuntu_24_04.id

  vpc_cidr_block     = "${var.cidr_header}.0.0/16"
  create_nat_gateway = var.create_nat_gateway
  subnet_type        = var.subnet_type
  owner              = var.owner
  tag_header         = "${var.owner}-"

  subnet_map = merge([
    for idx, key in var.subnet_type : {
      for i, az_name in local.azs : "${key}${split("-", az_name)[2]}" => {
        type = key
        az   = az_name
        cidr = "${var.cidr_header}.${i + (idx * 10 + 1)}.0/24"
        rt = key == "private" ? "${key}${split("-", az_name)[2]}" : (
          key
        )
      }
    }
  ]...)

  route_map = {
    for item in flatten([
      for type in var.subnet_type :
      type == "private" ? [
        for az in local.azs : {
          key  = "private${split("-", az)[2]}"
          type = type
        }
        ] : [
        {
          key  = type
          type = type
        }
      ]
      ]) : item.key => {
      type = item.type
    }
  }

  inbound_ports = [
    { from = 80, to = 80 },
    { from = 443, to = 443 },
    { from = 8000, to = 8000 }
  ]

  node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    # ECR 레포지토리 이미지 읽기
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    # SSM: SSH 없이 터미널 접속 가능
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    # Logging: 파드 및 시스템 로그 전송
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    # S3: 설정 파일이나 이미지 읽기 (필요 시 수정)
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
}
