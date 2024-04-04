variable "identifier" {
  description = "Unique identifier to differentiate global resources."
  type        = string
  validation {
    condition     = length(var.identifier) > 2
    error_message = "Identifier must be at least 3 characters"
  }
}

variable "kubernetes_version" {
  description = "The Kubernetes version the cluster runs on."
  type        = string
  default     = "1.29"
}

variable "subnets" {
  description = "A list of IDs of subnets for the subnet group and potentially the RDS proxy."
  type        = list(string)
  validation {
    condition     = length(var.subnets) > 0
    error_message = "List of subnets must contain at least one element"
  }
  validation {
    condition     = !contains([for v in var.subnets : startswith(v, "subnet-")], false)
    error_message = "Elements must be valid subnet IDs"
  }
}

variable "security_groups" {
  description = "A list of IDs of subnets for the subnet group and potentially the RDS proxy."
  type        = list(string)

  validation {
    condition     = !contains([for v in var.security_groups : startswith(v, "sg-")], false)
    error_message = "Elements must be valid security group IDs"
  }
}

variable "disk_size" {
  description = "Disk size in GiB of the node group."
  type        = number
  default     = 20
}

variable "instance_types" {
  description = "Types of the instances in the node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "desired_size" {
  description = "Desired amount of nodes in the node group."
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum amount of nodes in the node group."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum amount of nodes in the node group."
  type        = number
  default     = 1
}

vairable "pod_roles" {
  description = "A list of objects which define IAM roles which can be assumed by pods via ServiceAccounts."
  type = list(object({
    identifier = string
    policies = list(string)
  }))
  default = []
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
