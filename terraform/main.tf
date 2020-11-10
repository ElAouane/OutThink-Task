provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "aws_vpc" "default" {
  default = "true"
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_availability_zones" "default" {
  state = "available"
}

# ---------------------------------------------------------------------
#      Kubernetes AWS EKS cluster (Kubernetes control plane)
# ---------------------------------------------------------------------

resource "aws_eks_cluster" "voting_app_eks_cluster" {
  name     = var.eks-cluster-name
  role_arn = aws_iam_role.hamzaVotingApp-eks-cluster.arn
  version  = var.kubernetes-version

  vpc_config {
    subnet_ids = [for subnet in [for value in aws_subnet.voting_app_subnet : value] : subnet.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.hamzaVotingApp-eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.hamzaVotingApp-eks-cluster-AmazonEKSServicePolicy,
  ]
}


### ---------------------------------------------------------------------
###      Kubernetes AWS EKS node group (Kubernetes nodes)
### ---------------------------------------------------------------------
# create a ssh key
resource "aws_key_pair" "ssh" {
  key_name   = "eks-ssh"
  public_key = templatefile("${var.ssh_public_key}", {})
}
# create AWS EKS cluster - node group
resource "aws_eks_node_group" "hamzaVotingApp_node" {
  cluster_name    = aws_eks_cluster.voting_app_eks_cluster.name
  node_group_name = "${var.eks-cluster-name}-node-group"
  node_role_arn   = aws_iam_role.hamzaVotingApp-eks-cluster-node-group.arn
  subnet_ids      = [for subnet in [for value in aws_subnet.voting_app_subnet : value] : subnet.id]

  instance_types = ["t3.micro"]
  tags           = var.custom_tags

  scaling_config {
    desired_size = var.desired_number_nodes
    max_size     = var.max_number_nodes
    min_size     = var.min_number_nodes
  }

  remote_access {
    ec2_ssh_key               = aws_key_pair.ssh.key_name
    source_security_group_ids = list(aws_security_group.eks_cluster_node_group.id)
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_eks_cluster.voting_app_eks_cluster,
    aws_key_pair.ssh,
    aws_security_group.eks_cluster_node_group,
    aws_iam_role_policy_attachment.hamzaVotingApp-eks-cluster-node-group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.hamzaVotingApp-eks-cluster-node-group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.hamzaVotingApp-eks-cluster-node-group-AmazonEC2ContainerRegistryReadOnly,
  ]
}


# Uncomment to create Security Group rule for Kubernetes SSH port 22, NodePort 30111

resource "aws_security_group_rule" "this" {
  for_each = toset(var.tcp_ports)

  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = list("0.0.0.0/0")
  security_group_id = aws_eks_node_group.hamzaVotingApp_node.resources[0].remote_access_security_group_id

  depends_on = [
    aws_eks_node_group.hamzaVotingApp_node

  ]
}
