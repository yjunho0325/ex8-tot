resource "aws_iam_role" "cluster_role" {
  name = "${local.tag_header}eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
  tags = { Name = "${local.tag_header}eks-cluster-role" }
}
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}
resource "aws_iam_role" "node_role" {
  name = "${local.tag_header}eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "${local.tag_header}eks-node-role" }
}
resource "aws_iam_role_policy_attachment" "node_policy" {
  for_each   = toset(local.node_policies)
  policy_arn = each.value
  role       = aws_iam_role.node_role.name
}

# #################################################################################

resource "aws_eks_cluster" "k8s" {
  name     = "${local.tag_header}eks-cluster"
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids = [for s in aws_subnet.subnet : s.id if lookup(s.tags, "Type", "") == "cluster"]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
  tags       = { Name = "${local.tag_header}eks-cluster" }
}

resource "aws_launch_template" "launch_template" {
  name_prefix   = "${local.tag_header}k8s-node-"
  image_id      = data.aws_ami.eks_al2023_latest.id
  instance_type = "t3.small"
  key_name      = "std08-00-key"

  vpc_security_group_ids = [
    aws_security_group.eks_node_sg.id,
    aws_security_group.ssh_sg.id,
    aws_security_group.internal_alb_sg.id,
    aws_eks_cluster.k8s.vpc_config[0].cluster_security_group_id
  ]

  update_default_version = true
  user_data = base64encode(<<-EOT
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${aws_eks_cluster.k8s.name}
        apiServerEndpoint: ${aws_eks_cluster.k8s.endpoint}
        certificateAuthority: ${aws_eks_cluster.k8s.certificate_authority[0].data}
        cidr: ${aws_eks_cluster.k8s.kubernetes_network_config[0].service_ipv4_cidr}
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.tag_header}eks-node" }
  }
  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${local.tag_header}eks-node-vol" }
  }
  tags = { Name = "${local.tag_header}k8s-node-lt" }
}

resource "aws_eks_node_group" "eks_node_group" {
  node_group_name = "${local.tag_header}eks-node-group"
  cluster_name    = aws_eks_cluster.k8s.name
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = [for s in aws_subnet.subnet : s.id if lookup(s.tags, "Type", "") == "cluster"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  launch_template {
    name    = aws_launch_template.launch_template.name
    version = aws_launch_template.launch_template.latest_version # 삭제/version = $Default
  }
  depends_on = [aws_iam_role_policy_attachment.node_policy]
}
