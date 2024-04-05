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

resource "aws_iam_role_policy_attachment" "ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
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

################################
# EKS Cluster                  #
################################

resource "aws_eks_cluster" "main" {
  name                      = var.identifier
  version                   = var.kubernetes_version
  role_arn                  = aws_iam_role.master.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids         = var.subnets
    security_group_ids = var.security_groups
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

################################
# IAM Roles for Pods           #
################################

# OIDC provider to map IAM roles to kubernetes service accounts
data "tls_certificate" "main" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.main.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# creating the IAM roles
data "aws_iam_policy_document" "main" {
  count = length(var.service_accounts)

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.service_accounts[count.index]["name_space"]}:${var.service_accounts[count.index]["service_account"]}"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.main.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "main" {
  count              = length(var.service_accounts)
  assume_role_policy = data.aws_iam_policy_document.main[count.index].json
  name               = var.service_accounts[count.index]["iam_role_name"]
}

# map each policy to it's role from tree like objects
locals {
  policy_mapping = flatten([for i, v in var.service_accounts : [for w in v["policies"] : {
    role       = aws_iam_role.main[i].name,
    policy_arn = w
  }]])
}

resource "aws_iam_role_policy_attachment" "main" {
  count      = length(local.policy_mapping)
  role       = local.policy_mapping[count.index]["role"]
  policy_arn = local.policy_mapping[count.index]["policy_arn"]
}

# Kubernetes provider to create ServiceAccounts inside the EKS cluster
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.identifier]
    command     = "aws"
  }
}

# create a ServiceAccount inside Kubernetes mapped to an IAM role for each role
resource "kubernetes_service_account" "main" {
  count = length(var.service_accounts)

  metadata {
    name      = var.service_accounts[count.index]["service_account"]
    namespace = var.service_accounts[count.index]["name_space"]
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.main[count.index].arn
    }
  }
}
