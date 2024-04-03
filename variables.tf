variable "identifier" {
  description = "Unique identifier to differentiate global resources."
  type        = string
  validation {
    condition     = length(var.identifier) > 2
    error_message = "Identifier must be at least 3 characters"
  }
}

variable "vpc" {
  description = "ID of the subnets' VPC."
  type        = string
  validation {
    condition     = startswith(var.vpc, "vpc-")
    error_message = "Must be valid VPC ID"
  }
}

variable "subnets" {
  description = "A list of IDs of subnets for the subnet group and potentially the RDS proxy."
  type        = list(string)
  validation {
    condition     = length(var.subnets) > 1
    error_message = "List of subnets must contain at least 2 elements"
  }
  validation {
    condition     = !contains([for v in var.subnets : startswith(v, "subnet-")], false)
    error_message = "Elements must be valid subnet IDs"
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

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
