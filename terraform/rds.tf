# Security group and subnet group

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

/* 
    No ingress rule yet — the only thing allowed to reach RDS is the EKS
    nodes' security group, which doesn't exist until Step 5. We'll add the
    specific ingress rule then, referencing both security groups. Until that
    rule exists, this security group allows nothing in at all. 
*/
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Controls inbound access to RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Passwords generation and secrets manager

resource "random_password" "db" {
  length  = 32
  special = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}/db-credentials"
  description = "PostgreSQL credentials for the contact form app"

  tags = {
    Name = "${var.project_name}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    DB_HOST     = aws_db_instance.main.address
    DB_PORT     = tostring(aws_db_instance.main.port)
    DB_NAME     = aws_db_instance.main.db_name
    DB_USER     = aws_db_instance.main.username
    DB_PASSWORD = random_password.db.result
  })
}

# RDS PostgreSQL instance

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type       = "gp3"
  storage_encrypted  = true

  db_name  = "contactform"
  username = "contactform"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot  = true

  tags = {
    Name = "${var.project_name}-db"
  }
}