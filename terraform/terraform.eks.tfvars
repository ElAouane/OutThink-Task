aws_region     = "eu-west-1"
aws_access_key = ""
aws_secret_key = ""
ssh_public_key = "./ssh/eks-ssh.pub"
custom_tags = {
  Name      = "hamzaelaouane-eks-cluster-tag"
  Terraform = "true"
  Delete    = "true"
}

eks-cluster-name   = "hamzaelaouane-eks-cluster"
kubernetes-version = "1.16"

desired_number_nodes = 5
max_number_nodes     = 5
min_number_nodes     = 1

tcp_ports = ["22", "31000", "31001"]
