# Cluster: Service

This module creates a service insdie the ECS cluster and allows the definition of a service namespace for cluster internal service communication.

## Contents

- [Requirements](#requirements)
- [Inputs](#inputs)
- [Outputs](#outputs)

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.0  |
| aws       | >= 5.20 |

## Inputs

| Name               | Description                                                                                                                        | Type           | Default  | Required |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------- | :------: |
| identifier         | The unique identifier to differentiate resources.                                                                                  | `string`       | n/a      |   yes    |
| cluster_id         | The ID of the ECS cluster.                                                                                                         | `string`       | n/a      |   yes    |
| region             | The region in which the service is deployed.                                                                                       | `string`       | n/a      |   yes    |
| cpu_architecture   | The architecture of the CPU. Valid values are: 'X86_64' and 'ARM64'.                                                               | `string`       | "X86_64" |    no    |
| dns_namespace      | The DNS namespace under which the service is available.                                                                            | `string`       | null     |    no    |
| vpc_id             | The ID of the VPC in which the cluster is placed.                                                                                  | `string`       | n/a      |   yes    |
| execution_role_arn | The ARN of the execution IAM role for the ECS service.                                                                             | `string`       | n/a      |   yes    |
| policies           | A list of IAM policy ARNs for the task's IAM role.                                                                                 | `list(string)` | []       |    no    |
| container_port     | The port on which the containers will be exposed.                                                                                  | `number`       | n/a      |   yes    |
| subnets            | List of IDs of the subnets in which the Fargate tasks will be deployed.                                                            | `list(string)` | n/a      |   yes    |
| security_groups    | List of security group IDs the Fargate tasks will hold.                                                                            | `list(string)` | []       |    no    |
| public_ip          | A flag for wether or not assigning a public IP address to the containers.                                                          | `bool`         | false    |    no    |
| target_group       | Object to define target group for the service to join. Only needed if the service needs to be exposed publicly by a load balancer. | `object`       | null     |    no    |
| autoscaling        | Object to define the auto scaling behavior of the Fargate tasks inside the service.                                                | `object`       | null     |    no    |
| image              | Object of the image which will be pulled by the container definition of the Fargate tasks.                                         | `object`       | null     |    no    |
| log_config         | Object to define logging configuration for the container in the Fargate task to CloudWatch.                                        | `object`       | null     |    no    |
| task_count         | Desired number of Fargate task replicas running under the service.                                                                 | `number`       | 1        |    no    |
| task_cpu           | Number of virtual CPU units assigned to each Fargate task.                                                                         | `number`       | 256      |    no    |
| task_memory        | Amount of memory in MiB assigned to each Fargate task.                                                                             | `number`       | 512      |    no    |
| env_variables      | A map of environment variables for the Fargate task initialized at runtime.                                                        | `map(string)`  | {}       |    no    |
| tags               | A map of tags to add to all resources.                                                                                             | `map(string)`  | {}       |    no    |

### `target_group`

| Name              | Description                                                                                         | Type     | Default | Required |
| ----------------- | --------------------------------------------------------------------------------------------------- | -------- | ------- | :------: |
| arn               | The ARN of the target group.                                                                        | `string` | n/a     |   yes    |
| lb_security_group | The security group ID of the load balancer to allow him access to the container inside the service. | `string` | n/a     |   yes    |

### `autoscaling`

| Name                      | Description                                          | Type     | Default | Required |
| ------------------------- | ---------------------------------------------------- | -------- | ------- | :------: |
| max_count                 | The maximum amount of tasks spun up at a time.       | `number` | n/a     |   yes    |
| min_count                 | The minimum amount of tasks spun up at a time.       | `number` | n/a     |   yes    |
| cpu_target_utilization    | The desired average CPU utilization of the tasks.    | `number` | 50      |    no    |
| memory_target_utilization | The desired average memory utilization of the tasks. | `number` | 50      |    no    |

### `image`

| Name | Description           | Type     | Default | Required |
| ---- | --------------------- | -------- | ------- | :------: |
| uri  | The URI of the image. | `string` | n/a     |   yes    |

### `log_config`

| Name              | Description                                                                                                                | Type     | Default | Required |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------- | -------- | ------- | :------: |
| retention_in_days | Specifies the number of days the log events shall be retained. Valid values: 1, 3, 5, 7, 14, 30, 365 and 0 (never expire). | `number` | n/a     |   yes    |

## Outputs

| Name           | Description                                                                                                                                              |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| dns_endpoint   | The static private DNS endpoint under which the service is available.                                                                                    |
| log_group_arn  | The ARN of the CloudWatch log group.                                                                                                                     |
| security_group | The ID of the created security group for which to allow access to this service. Will be null if the service is assigned to a load balancer target group. |
