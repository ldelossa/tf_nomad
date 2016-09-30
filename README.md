# Nomad Cluster Terraform

### Description
This terraform module will deploy a variable number of consul, nomad server, and nomad client machines. Nomad Client machines are responsible for actually running your tasks, while Masters are used to orchestrate the cluster. Consul is used for clustering and service discovery. Once the cluster is launched you will have the IP's of each instance displayed.

### Usage
The defaults.tf file is used and is hard linked into the directory. You will have to copy the specific environment's .tf file you plan on deploying into this directory. This terraform script explicitly connects to the deployed instance to provision the instance.

The module will expect one mandatory (no defaults provided) variables to be provided on deploy. These are

```
variable "consul_token" {}

```

consul_token is the root token used for administrative purposes on the consul cluster. This is the token that the rest of the cluster uses to have full permissions to the consul cluster.

ssh_key_path in var.tf should be changed to point to the Operation's pem file for the specified environment. 

Pay attention to the rest of the vars.tf file to customize your nomad cluster accordingly.
# tf_nomad
