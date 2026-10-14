output "bucket_id" {
  description = "Name of the artifact bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the artifact bucket."
  value       = aws_s3_bucket.this.arn
}

output "seed_key" {
  description = "Object key of the seed package."
  value       = aws_s3_object.seed.key
}

output "seed_version_id" {
  description = "Version id of the seed package."
  value       = aws_s3_object.seed.version_id
}

output "bucket_policy_id" {
  description = "ID of the bucket policy resource, for dependency ordering."
  value       = aws_s3_bucket_policy.this.id
}
