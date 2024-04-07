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
  name   = "${var.identifier}-EKSWokerAutoscaling"
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
  count           = length(var.node_groups)
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_groups[count.index]["identifier"]
  node_role_arn   = aws_iam_role.worker.arn
  subnet_ids      = var.node_groups[count.index]["subnets"]

  launch_template {
    id      = var.node_groups[count.index]["launch_template"]
    version = "$Latest"
  }

  scaling_config {
    desired_size = var.node_groups[count.index]["desired_size"]
    min_size     = var.node_groups[count.index]["min_size"]
    max_size     = var.node_groups[count.index]["max_size"]
  }

  dynamic "taint" {
    for_each = var.node_groups[count.index]["taints"]
    content {
      key    = taint.value["key"]
      value  = taint.value["value"]
      effect = taint.value["effect"]
    }
  }

  tags = var.tags
}

# OIDC provider to map IAM roles to kubernetes service accounts
data "tls_certificate" "main" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.main.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Kubernetes provider to create ServiceAccounts from this Terraform setup
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.identifier]
    command     = "aws"
  }
}

# Helm provider to create controllers for load balancing and logging this Terraform setup
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.id]
      command     = "aws"
    }
  }
}

################################
# IAM Roles for Pods           #
################################

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

  tags = var.tags
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

# create a ServiceAccount inside Kubernetes mapped to an IAM role for each role
# kubernetes provider used to create this resource
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

################################
# AWS Load Balancer Controller #
################################

# how to setup the controller: https://www.youtube.com/watch?v=ZfjpWOC5eoE
# alternatives explained: https://www.youtube.com/watch?v=RQbc_Yjb9ls

data "aws_iam_policy_document" "albc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.main.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "albc" {
  assume_role_policy = data.aws_iam_policy_document.albc.json
  name               = "${var.identifier}-RoleForAWSLoadBalancerController"

  tags = var.tags
}

resource "aws_iam_policy" "albc" {
  # got the IAM policy JSON file from the following repo:
  # https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v2.7.2/docs/install/iam_policy.json
  policy = local.albc_policy
  name   = "${var.identifier}-AWSLoadBalancerController"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "albc" {
  role       = aws_iam_role.albc.name
  policy_arn = aws_iam_policy.albc.arn
}

# helm provider used to create this resource
resource "helm_release" "albc" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "v1.7.2"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.id
  }

  set {
    name  = "image.tag"
    value = "v2.7.2"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.albc.arn
  }
}

# set tags on provided load balancer subnets for the controller to know where to place the load balancer
resource "aws_ec2_tag" "main" {
  count       = length(var.lb_subnets)
  resource_id = var.lb_subnets[count.index]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

################################
# FluentBit CloudWatch Logging #
################################

# great tutorial: https://www.youtube.com/watch?v=E_P4EqJQ-T0

data "aws_iam_policy_document" "assume_log" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:logs:fluentbit-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.main.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "log" {
  assume_role_policy = data.aws_iam_policy_document.assume_log.json
  name               = "${var.identifier}-RoleForFluentBit"

  tags = var.tags
}

data "aws_iam_policy_document" "log" {
  statement {
    effect = "Allow"

    actions = [
      "logs:PutLogEvents",
      "logs:Describe*",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "log" {
  policy = data.aws_iam_policy_document.log.json
  name   = "${var.identifier}-FluentBitCloudWatch"

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "log" {
  role       = aws_iam_role.log.name
  policy_arn = aws_iam_policy.log.arn
}

# kubernetes provider used to create this resource
resource "kubernetes_namespace" "log" {
  metadata {
    name = "logs"
  }
}

# kubernetes provider used to create this resource
resource "kubernetes_service_account" "log" {
  metadata {
    name      = "fluentbit-sa"
    namespace = kubernetes_namespace.log.id
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.log.arn
    }
  }

  automount_service_account_token = true
}

resource "helm_release" "log" {
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = "0.1.32" # https://artifacthub.io/packages/helm/aws/aws-for-fluent-bit
  name       = "aws-fluent-bit"
  namespace  = kubernetes_namespace.log.id

  values = [
    templatefile("./aws-fluentbit.tpl", {
      logGroupName = "${var.identifier}-fluentbit"
      region       = var.region
    })
  ]
}
