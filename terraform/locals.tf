# locals.tf
locals {
  instance_name = "web-server"
  environment   = "development"
  common_tags = {
    Project     = "pruebafinal-desafiolatam"
    Environment = local.environment
  }
}
