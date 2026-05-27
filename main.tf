provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAIOSFODNN7EXAMPLE"       # Hardcoded creds
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# S3 bucket — public, no encryption
resource "aws_s3_bucket" "data" {
  bucket = "my-company-prod-data"
  acl    = "private"

  versioning {
    enabled = false                         # No versioning
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  # Intentionally omitted — no encryption at rest
}

# Security Group — wide open
resource "aws_security_group" "open" {
  name = "allow_all"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]            # Open to world
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS — publicly accessible, no encryption
resource "aws_db_instance" "main" {
  identifier              = "prod-db"
  engine                  = "mysql"
  instance_class          = "db.t2.micro"
  username                = "admin"
  password                = "Password123!"  # Hardcoded
  publicly_accessible     = true            # Exposed to internet
  storage_encrypted       = false           # No encryption
  backup_retention_period = 0               # No backups
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.open.id]
}

# IAM — overly permissive
resource "aws_iam_policy" "admin" {
  name = "FullAccessPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"                        # Wildcard - all actions
      Resource = "*"                        # All resources
    }]
  })
}

# EC2 — IMDSv1, no monitoring
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  key_name      = "my-key"

  metadata_options {
    http_tokens = "optional"               # IMDSv1 enabled (SSRF risk)
  }

  monitoring = false                       # No detailed monitoring

  user_data = <<-EOF
    #!/bin/bash
    echo "admin:Password123!" | chpasswd   # Hardcoded creds in userdata
  EOF
}
