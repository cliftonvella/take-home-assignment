project = "eks-test"

aws_account_id = "<your_aws_account_id>"

az_count = 3

default_instance_type = "t3.micro"

instance_types = {
  "eks_node_group" = "t3.medium"
}

#list of AMIs that are currently being used
ami_ids = {
  "bastion" : "ami-0e54671bdf3c8ed8d"
}

cluster_name    = "eks-test"
cluster_version = "1.31"

ingress_allowed_cidrs = [ <comma-separated list of public IPs> ]
bastion_allowed_cidrs = [ <comma-separated list of public IPs> ]