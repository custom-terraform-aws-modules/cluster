output "ecr_repository" {
  description = "Object of the created ECR repository if created."
  value = {
    uri = try(aws_ecr_repository.main[0].repository_url, null)
    arn = try(aws_ecr_repository.main[0].arn, null)
  }
}

output "log_arn" {
  description = "ARN of the created CloudWatch log group."
  value       = try(aws_cloudwatch_log_group.main.arn, null)
}
