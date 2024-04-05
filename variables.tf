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
  default     = null # will cause the use of the latest Kubernetes version
}

variable "subnets" {
  description = "A list of subnet IDs for the managed master nodes to run."
  type        = list(string)
  validation {
    condition     = length(var.subnets) > 0
    error_message = "List of subnets must contain at least one element"
  }
}

variable "security_groups" {
  description = "A list of security group IDs to be applied to the entire cluster."
  type        = list(string)
  default     = []
}

variable "node_groups" {
  description = "A list of objects to define a group of worker nodes inside the cluster."
  type = list(object({
    identifier      = string
    subnets         = list(string)
    desired_size    = optional(number, 1)
    min_size        = optional(number, 1)
    max_size        = optional(number, 1)
    launch_template = string
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = []
  validation {
    condition     = !contains([for v in var.node_groups : length(v["identifier"]) > 2], false)
    error_message = "Identifier of node groups must be at least 3 characters"
  }
  validation {
    condition     = length(toset([for v in var.node_groups : v["identifier"]])) == length(var.node_groups)
    error_message = "Identifier of node groups must be unique"
  }
  validation {
    condition     = !contains([for v in var.node_groups : v["min_size"] <= v["max_size"]], false)
    error_message = "Minimum size of node groups must be at equal or less than maximum size"
  }
  validation {
    condition = length(flatten([for v in var.node_groups : toset([for w in v["taints"] : w["key"]])])) == length(
    flatten([for v in var.node_groups : [for w in v["taints"] : w["key"]]]))
    error_message = "Taint keys must be unique in the same node group"
  }
  validation {
    condition = !contains(flatten([for v in var.node_groups : [for w in v["taints"] : w["effect"] == "NO_SCHEDULE" || (
    w["effect"] == "NO_EXECUTE") || w["effect"] == "PREFER_NO_SCHEDULE"]]), false)
    error_message = "Taint effect must be either 'NO_SCHEDULE', 'NO_EXECUTE' or 'PREFER_NO_SCHEDULE'"
  }
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
  validation {
    condition     =  length(toset([for v in var.service_accounts : "${v["name_space"]}:${v["service_account"]}"])) == length(var.service_accounts)
    error_message = "Name space with service account name must be unique"
  }
  validation {
    condition     = length(toset([for v in var.service_accounts : v["iam_role_name"]])) == length(var.service_accounts)
    error_message = "IAM role names in service accounts must be unique"
  }
  validation {
    condition     = !contains([for v in var.service_accounts : length(v["policies"]) > 0], false)
    error_message = "At least one policy must be supplied to create an IAM role"
  }
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
