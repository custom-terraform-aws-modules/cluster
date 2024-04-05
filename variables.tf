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
  default     = null
}

variable "subnets" {
  description = "A list of subnet IDs for the managed master nodes to run."
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
  description = "A list of security group IDs to be applied to the entire cluster."
  type        = list(string)
  default     = []
  validation {
    condition     = !contains([for v in var.security_groups : startswith(v, "sg-")], false)
    error_message = "Elements must be valid security group IDs"
  }
}

variable "node_groups" {
  description = "A list of objects to define a group of worker nodes inside the cluster."
  type = list(object({
    identifier   = string
    subnets      = list(string)
    desired_size = optional(number, 1)
    min_size     = optional(number, 1)
    max_size     = optional(number, 1)
    launch_template = object({
      id      = string
      version = optional(string, "$Latest")
    })
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = []
}

variable "service_accounts" {
  description = "A list of objects to create IAM roles which are automatically mapped to ServiceAccounts inside Kubernetes."
  type = list(object({
    name_space      = string
    service_account = string
    iam_role_name   = string
    policies        = list(string)
  }))
  default = []
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
