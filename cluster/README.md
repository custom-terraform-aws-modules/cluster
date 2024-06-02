# Cluster: Cluster

This module creates the ECS cluster and is the foundation for the other modules of this repository to build on top of.

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

| Name       | Description                                                              | Type          | Default | Required |
| ---------- | ------------------------------------------------------------------------ | ------------- | ------- | :------: |
| identifier | The unique identifier to differentiate resources.                        | `string`      | n/a     |   yes    |
| log_config | Object to define logging configuration for the ECS master to CloudWatch. | `object`      | null    |    no    |
| tags       | A map of tags to add to all resources.                                   | `map(string)` | {}      |    no    |

### `log_config`

| Name              | Description                                                                                                                | Type     | Default | Required |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------- | -------- | ------- | :------: |
| retention_in_days | Specifies the number of days the log events shall be retained. Valid values: 1, 3, 5, 7, 14, 30, 365 and 0 (never expire). | `number` | n/a     |   yes    |

## Outputs

| Name               | Description                                                               |
| ------------------ | ------------------------------------------------------------------------- |
| id                 | The ID of the ECS cluster.                                                |
| execution_role_arn | The ARN of the execution IAM role for the ECS services.                   |
| log_group_arn      | The ARN of the CloudWatch log group created for the ECS master to log to. |
