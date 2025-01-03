# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(
    local.common_tags,
    {
      Name = "main-vpc"
    }
  )
}

# Subnet Pública
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block             = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags = merge(
    local.common_tags,
    {
      Name = "public-subnet"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    local.common_tags,
    {
      Name = "main-igw"
    }
  )
}

# Route Table Pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(
    local.common_tags,
    {
      Name = "public-route-table"
    }
  )
}

# Route Table Association para la subnet pública
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Subnet Privada
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block             = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
  
  tags = merge(
    local.common_tags,
    {
      Name = "private-subnet"
    }
  )
}

# Route Table Privada
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    local.common_tags,
    {
      Name = "private-route-table"
    }
  )
}

# Route Table Association para la subnet privada
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir tráfico en el puerto 3000 desde cualquier IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "web-security-group"
    }
  )
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type              = var.instance_type
  subnet_id                  = aws_subnet.public.id
  vpc_security_group_ids     = [aws_security_group.web.id]
  associate_public_ip_address = true
  availability_zone          = var.availability_zone
  key_name                   = var.key_name

# Provisionador para copiar los archivos
provisioner "file" {
  source      = "./api" # La carpeta de tu api
  destination = "/home/ec2-user/app"  # El destino en el EC2
 }
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
# Provisionador para ejecutar comandos en la instancia EC2
provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -",
      "sudo yum install -y nodejs",

      # Configurar logging para la aplicación Node.js
      "mkdir -p /home/ec2-user/app/logs",
      
      # Configurar PM2 para logging
      "cd /home/ec2-user/app",
      "sudo npm install -g pm2",
      "npm install",
      "pm2 start app.js --name mi-app-node --log /home/ec2-user/app/logs/app.log",
      "pm2 save",
      
      # Configurar rotación de logs
      <<-EOT
      sudo tee /etc/logrotate.d/pm2-ec2-user > /dev/null <<EOF
      /home/ec2-user/app/logs/*.log {
        su ec2-user ec2-user
        daily
        rotate 7
        compress
        delaycompress
        missingok
        notifempty
      }
      EOF
      EOT
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.instance_name
    }
  )
 }

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${local.instance_name}"
  retention_in_days = 3
  
  tags = merge(
    local.common_tags,
    {
      Name = "application_logs"
    }
  )
}

# SNS Topic para las alarmas de CloudWatch
resource "aws_sns_topic" "alarm_topic" {
  name = "cloudwatch-alarms-topic"
  tags = merge(
    local.common_tags,
    {
      Name = "alarm_topic"
    }
  )
}

# SNS Topic para las notificaciones procesadas
resource "aws_sns_topic" "sns_topic" {
  name = "processed-monitoring-notifications"
  tags = merge(
    local.common_tags,
    {
      Name = "sns_topic"
    }
  )
}

# SQS Queue para recibir alarmas
resource "aws_sqs_queue" "alarm_queue" {
  name                       = "monitoring-alarms-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 3600
  receive_wait_time_seconds  = 20

  tags = merge(
    local.common_tags,
    {
      Name = "alarm_queue"
    }
  )
}

# Suscripción del SNS Topic a SQS
resource "aws_sns_topic_subscription" "alarm_to_sqs" {
  topic_arn = aws_sns_topic.alarm_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.alarm_queue.arn
  depends_on = [aws_sns_topic.alarm_topic, aws_sqs_queue.alarm_queue]
}

# Política de SQS para permitir que SNS escriba
resource "aws_sqs_queue_policy" "alarm_queue_policy" {
  queue_url = aws_sqs_queue.alarm_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.alarm_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn": aws_sns_topic.alarm_topic.arn
          }
        }
      }
    ]
  })
  depends_on = [aws_sqs_queue.alarm_queue, aws_sns_topic.alarm_topic]
}

# Crear un bucket S3 privado
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.s3_bucket

  tags = merge(
    local.common_tags,
    {
      Name = "lambda_bucket"
    }
  )
}

# Política de bucket para hacer el bucket privado
resource "aws_s3_bucket_policy" "lambda_bucket_policy" {
  bucket = aws_s3_bucket.lambda_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.lambda_bucket.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.lambda_bucket.bucket}"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      }
    ]
  })
}

# Subir el archivo ZIP al bucket S3
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda/lambda_function.zip"
  source = "${path.module}/lambda/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "alarm_processor" {
  s3_bucket     = aws_s3_bucket.lambda_bucket.bucket
  s3_key        = aws_s3_object.lambda_zip.key
  function_name = "alarm-processor"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.sns_topic.arn
    }
  }

  role = aws_iam_role.lambda_execution_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment,
    aws_sns_topic.sns_topic,
    aws_s3_object.lambda_zip
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "alarm_processor"
    }
  )
}

# Log Group para Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/alarm-processor"
  retention_in_days = 3
  depends_on = [aws_lambda_function.alarm_processor]
}

# IAM Role para Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name = "alarm-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "lambda_execution_role"
    }
  )
}

# Política IAM para Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "alarm-processor-policy"
  description = "Policy for alarm processor Lambda function"
  policy      = data.aws_iam_policy_document.lambda_policy.json

  tags = merge(
    local.common_tags,
    {
      Name = "lambda_policy"
    }
  )
}

# Adjuntar la política al rol de Lambda
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
  depends_on = [aws_iam_role.lambda_execution_role, aws_iam_policy.lambda_policy]
}

# Event Source Mapping entre SQS y Lambda
resource "aws_lambda_event_source_mapping" "alarm_queue_mapping" {
  event_source_arn = aws_sqs_queue.alarm_queue.arn
  function_name    = aws_lambda_function.alarm_processor.arn
  batch_size       = 1
  enabled          = true

  depends_on = [
    aws_lambda_function.alarm_processor,
    aws_sqs_queue.alarm_queue,
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "alarm_queue_mapping"
    }
  )
}

# Suscripción de email al SNS
resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Alarmas de CloudWatch
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_alarm" {
  alarm_name          = "EC2-CPU-Utilization-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period             = "300"
  statistic          = "Average"
  threshold          = var.cpu_threshold
  alarm_description  = "Esta alarma se activará cuando el uso de CPU supere el ${var.cpu_threshold}%"
  alarm_actions      = [aws_sns_topic.alarm_topic.arn]
  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "ec2_cpu_alarm"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "network_in_alarm" {
  alarm_name          = "EC2-Network-In-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period             = "300"
  statistic          = "Average"
  threshold          = var.network_in_threshold
  alarm_description  = "Alarma cuando el tráfico de red entrante es alto"
  alarm_actions      = [aws_sns_topic.alarm_topic.arn]
  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "network_in_alarm"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "status_check_alarm" {
  alarm_name          = "EC2-Status-Check-Failed-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period             = "300"
  statistic          = "Maximum"
  threshold          = "0"
  alarm_description  = "Esta alarma se activará si falla algún status check de la instancia"
  alarm_actions      = [aws_sns_topic.alarm_topic.arn]
  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "status_check_alarm"
    }
  )
}