resource "aws_security_group" "external_alb_sg" {
  name        = "${local.tag_header}external-alb-sg"
  vpc_id      = aws_vpc.vpc.id
  description = "Allow HTTP and HTTPS Traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0 # 모든 포트
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}external-alb-sg" }
}

# ----------------------------------------------------------------
# Security Group Chaining: ALB 보안 그룹에서 HTTP 트래픽을 허용하는 규칙을 추가하여 ALB가 HTTP 트래픽을 수신할 수 있도록 합니다.
resource "aws_security_group" "internal_alb_sg" {
  name        = "${local.tag_header}internal-alb-sg"
  vpc_id      = aws_vpc.vpc.id
  description = "Allow HTTP Traffic"

  egress {
    from_port   = 0 # 모든 포트
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}internal-alb-sg" }
}

# 보안 그룹 규칙 생성
resource "aws_security_group_rule" "allow_alt_to_http" {
  # 리스트를 맵으로 변환하여 반복문 돌림
  for_each = { for p in local.inbound_ports : "${p.from}-${p.to}" => p }

  type      = "ingress"
  protocol  = "tcp"
  from_port = each.value.from
  to_port   = each.value.to

  # 이 보안 규칙을 어디에 추가 할 것인가
  security_group_id = aws_security_group.internal_alb_sg.id
  # 누구를 추가할 것인가
  source_security_group_id = aws_security_group.external_alb_sg.id
}

# ################################################################################
# SSH
# ================================================================================
resource "aws_security_group" "ssh_sg" {
  name        = "${local.tag_header}ssh-sg"
  vpc_id      = aws_vpc.vpc.id
  description = "Allow SSH Traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0 # 모든 포트
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}ssh-sg" }
}

# ################################################################################
# NAT Instance
# ================================================================================
resource "aws_security_group" "nat_sg" {
  name        = "${local.tag_header}nat-sg"
  description = "Security Group for NAT Instance"
  vpc_id      = aws_vpc.vpc.id

  # 1. 관리자용 SSH 접속 (이안님 PC에서만)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실무에선 본인 IP 권장
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  # 4. 외부(인터넷)로 모든 패킷 내보내기 (필수)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}nat-sg" }
}

# ################################################################################
# EKS NODE
# ================================================================================
# EKS 노드 간 내부 통신 및 클러스터 통신을 위한 보안 그룹
resource "aws_security_group" "eks_node_sg" {
  name        = "${local.tag_header}eks-node-sg"
  description = "Security group for all nodes in the cluster to allow internal communication"
  vpc_id      = aws_vpc.vpc.id

  # 1. 노드 간 모든 통신 허용 (Self-reference)
  # 노드 그룹 내의 파드들이 서로 통신하기 위해 필수적입니다.
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow nodes to communicate with each other"
  }

  # 2. 컨트롤 플레인으로부터의 Kubelet 통신 허용
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    description = "Allow Kubelet API to communicate with control plane"
    # 보안을 위해 클러스터 보안 그룹만 허용하도록 설정 가능
    # security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_primary_security_group_id]
  }

  # 3. 아웃바운드 규칙 (모든 곳으로 나가는 트래픽 허용)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}eks-node-sg" }
}
