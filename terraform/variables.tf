variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR blocks for subnets"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key name"
  type        = string
  default = "desafiolatam-cursodevops"
}

variable "private_key_path" {
  default = "./desafiolatam-cursodevops.pem"
}

variable "availability_zone" {
  description = "La zona de disponibilidad para las instancias"
  type        = string
  default     = "sa-east-1a"  # Define una zona por defecto
}

variable "s3_bucket" {
  type        = string
  description = "The name of the S3 bucket"
  default     = "pruebafinal-terraform-bucket2025"
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
  sensitive   = true
}

variable "aws_session_token" {
  type        = string
  description = "AWS Session Token"
  sensitive   = true
}

variable "tf_api_token" {
  description = "Terraform Cloud API Token"
  type        = string
  sensitive   = true
}

# Email address to send notifications
variable "notification_email" {
  type        = string
  description = "The email address to send notifications"
}

variable "network_in_threshold" {
  description = "Network In threshold in bytes"
  type        = number
  default     = 10000 # 10 KB
}

variable "cpu_threshold" {
  description = "CPU Utilization threshold percentage"
  type        = number
  default     = 80
}