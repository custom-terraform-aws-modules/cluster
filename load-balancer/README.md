# Cluster: Load Balancer

This module creates a load balancer and allows to define target groups which a service can join to expose the service to the public internet.

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

| Name          | Description                                                             | Type           | Default | Required |
| ------------- | ----------------------------------------------------------------------- | -------------- | ------- | :------: |
| identifier    | The unique identifier to differentiate resources.                       | `string`       | n/a     |   yes    |
| vpc_id        | The ID of the VPC in which the load balancer will be deployed.          | `string`       | n/a     |   yes    |
| subnets       | List of IDs of the subnets in which the load balancer will be deployed. | `list(string)` | n/a     |   yes    |
| target_groups | List of objects to define target groups served by the load balancer.    | `list(object)` | []      |    no    |
| tags          | A map of tags to add to all resources.                                  | `map(string)`  | {}      |    no    |

### `target_groups`

| Name              | Description                                                                           | Type     | Default | Required |
| ----------------- | ------------------------------------------------------------------------------------- | -------- | ------- | :------: |
| name              | An unique name for the target group.                                                  | `string` | n/a     |   yes    |
| host_domain       | The public domain under which the target shall be available.                          | `string` | n/a     |   yes    |
| certificate_arn   | The ARN of the ACM certificate to verify ownership of the domain.                     | `string` | n/a     |   yes    |
| health_check_path | The path under which the load balancer shall perform health checks of the containers. | `string` | "/"     |    no    |

## Outputs

| Name          | Description                                                                |
| ------------- | -------------------------------------------------------------------------- |
| target_groups | List of objects for created target groups accessible by the load balancer. |
| dns_name      | The DNS name of the load balancer.                                         |
| zone_id       | The zone ID of the publicly hosted DNS zone of the load balancer.          |

### `target_groups`

| Name              | Description                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------- |
| arn               | The ARN of the created target group.                                                                 |
| lb_security_group | The security group ID of the load balancer to allow him in security group rules access to a service. |
