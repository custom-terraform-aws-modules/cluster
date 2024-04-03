################################
# Master IAM Roles             #
################################

data "aws_iam_policy_document" "master" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "master" {
  name               = "${var.identifier}-ServiceRoleForEKSMaster"
  assume_role_policy = data.aws_iam_policy_document.master.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "service" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.master.name
}

################################
# Worker IAM Roles             #
################################

data "aws_iam_policy_document" "worker" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "worker" {
  name               = "${var.identifier}-ServiceRoleForEKSWorker"
  assume_role_policy = data.aws_iam_policy_document.worker.json

  tags = var.tags
}

data "aws_iam_policy_document" "autoscaling" {
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeTags",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "autoscaling" {
  name   = "ed-eks-autoscaler-policy"
  policy = data.aws_iam_policy_document.autoscaling.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "autoscaling" {
  policy_arn = aws_iam_policy.autoscaling.arn
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "network_interface" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "xray" {
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.worker.name
}

# TODO give IAM permission to read ECR registries and S3 buckets

################################
# Security Groups              #
################################

resource "aws_security_group" "allow_tls" {
  name        = "${var.identifier}-allow-tls"
  description = "Allows TLS inbound traffic."
  vpc_id      = var.vpc

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.allow_tls.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "internet_access" {
  security_group_id = aws_security_group.allow_tls.id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
}

################################
# Kubectl Server               #
################################

resource "aws_key_pair" "kubectl" {
  key_name   = "${var.identifier}-kubectl"
  public_key = var.public_key

  tags = var.tags
}

resource "aws_instance" "kubectl" {
  key_name                    = aws_key_pair.kubectl.name
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = var.kubectl_subnet
  vpc_security_group_ids      = [aws_security_group.allow_tls.id]

  tags = var.tags
}

################################
# EKS Cluster                  #
################################

resource "aws_eks_cluster" "main" {
  name     = var.identifier
  role_arn = aws_iam_role.master.arn

  vpc_config {
    subnet_ids = var.subnets
  }

  tags = var.tags
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.identifier
  node_role_arn   = aws_iam_role.worker.arn
  subnet_ids      = var.subnets
  capacity_type   = "ON_DEMAND"
  disk_size       = var.disk_size
  instance_types  = var.instance_types

  remote_access {
    ec2_ssh_key               = aws_key_pair.kubectl.name
    source_security_group_ids = [aws_security_group.allow_tls.id]
  }

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = var.tags
}
