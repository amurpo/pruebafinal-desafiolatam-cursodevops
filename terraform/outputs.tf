# Outputs básicos de EC2
output "instance_id" {
  description = "ID of EC2 instance"
  value       = aws_instance.web.id
}

# No exponemos las IPs directamente, solo el nombre DNS público si es necesario
output "application_endpoint" {
  description = "Application endpoint"
  value       = "http://${aws_instance.web.public_dns}:3000"
}

# Información básica de red
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

# Información de monitoreo
output "cloudwatch_alarms_status" {
  description = "Names of configured alarms"
  value = {
    cpu_alarm    = aws_cloudwatch_metric_alarm.ec2_cpu_alarm.alarm_name
    network_alarm = aws_cloudwatch_metric_alarm.network_in_alarm.alarm_name
    status_alarm = aws_cloudwatch_metric_alarm.status_check_alarm.alarm_name
  }
}

# Información básica de recursos serverless
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.alarm_processor.function_name
}

# Estado del despliegue
output "deployment_status" {
  description = "Status of key infrastructure components"
  value = {
    vpc_status     = aws_vpc.main.id != "" ? "deployed" : "failed"
    instance_state = aws_instance.web.instance_state
  }
}