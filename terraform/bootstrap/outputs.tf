output "state_bucket_name" {
  description = "S3 bucket name to use as the 'bucket' value in every other Terraform config's backend block"
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table_name" {
  description = "DynamoDB table name to use as the 'dynamodb_table' value in every other Terraform config's backend block"
  value       = aws_dynamodb_table.tfstate_lock.name
}
