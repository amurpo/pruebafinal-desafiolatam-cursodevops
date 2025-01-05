# Prueba final Desafiolatam Curso Devops
[![Docker](https://github.com/amurpo/pruebafinal-desafiolatam-cursodevops/actions/workflows/deploy.yml/badge.svg)](https://github.com/amurpo/pruebafinal-desafiolatam-cursodevops/actions/workflows/deploy.yml "Docker Build & Push") [![Security](https://github.com/amurpo/pruebafinal-desafiolatam-cursodevops/actions/workflows/deploy.yml/badge.svg)](https://github.com/amurpo/pruebafinal-desafiolatam-cursodevops/actions/workflows/deploy.yml "Security Scan") [![Terraform](https://github.com/amurpo/pruebafinal-desafiolatam-cursodevops/actions/workflows/deploy.yml/badge.svg)](https://github.com/amurpo/pruebafinal-desafiolatam-cursodevops/actions/workflows/deploy.yml "Terraform Deploy")

Este proyecto utiliza GitHub Actions para automatizar el proceso de construcción, escaneo de seguridad y despliegue de una aplicación en AWS.

## Descripción

El pipeline de GitHub Actions está configurado para ejecutar los siguientes jobs:

1. **Build y Push de Docker**:
   - Compila la imagen Docker utilizando un Dockerfile multistage.
   - Hace push de la imagen construida a Amazon ECR (Elastic Container Registry).

2. **Escaneo de Seguridad**:
   - Realiza escaneos de seguridad de dependencias, imágenes Docker y archivos Terraform usando Snyk.

3. **Despliegue con Terraform**:
   - Despliega la infraestructura en AWS utilizando Terraform.

## Configuración del Pipeline

### Triggers

El pipeline se ejecuta en los siguientes eventos:
- Push a la rama `main`.
- Pull request a la rama `main`.

### Variables de Entorno

- `AWS_REGION`: Región de AWS.
- `ECR_REPOSITORY`: Repositorio de ECR.
- `TF_VERSION`: Versión de Terraform.

## Jobs

### 1. Docker Build and Push

Este trabajo realiza las siguientes acciones:
- Checkout del código fuente.
- Configuración de credenciales de AWS.
- Creación del repositorio ECR (si no existe).
- Login a Amazon ECR.
- Configuración de Docker Buildx.
- Cacheo de capas de Docker.
- Build y push de la imagen Docker a ECR.

### 2. Security Scan

Este trabajo realiza las siguientes acciones:
- Checkout del código fuente.
- Configuración de credenciales de AWS.
- Login a Amazon ECR.
- Configuración de Node.js.
- Instalación de Snyk CLI.
- Autenticación con Snyk.
- Escaneo de dependencias y Docker image de ECR.
- Escaneo de archivos Terraform usando Snyk.

### 3. Terraform Deploy

Este trabajo realiza las siguientes acciones:
- Checkout del código fuente.
- Configuración de credenciales de AWS.
- Creación de una clave privada temporal para SSH.
- Configuración de Terraform.
- Cacheo de archivos Terraform.
- Creación de archivo `terraform.tfvars`.
- Inicialización, planificación y aplicación de Terraform.
- Eliminación del archivo `terraform.tfvars` y la clave privada temporal.

## Uso

Para utilizar este pipeline, es necesario tener configuradas las siguientes variables y secretos:

- `AWS_ACCESS_KEY_ID`: Clave de acceso de AWS.
- `AWS_SECRET_ACCESS_KEY`: Clave secreta de AWS.
- `AWS_SESSION_TOKEN`: Token de sesión de AWS.
- `ECR_REPOSITORY`: Nombre del repositorio de ECR.
- `SNYK_TOKEN`: Token de autenticación de Snyk.
- `TF_API_TOKEN`: Token de API de Terraform Cloud.
- `NOTIFICATION_EMAIL`: Dirección de correo electrónico para notificaciones.

### Ejecución del Pipeline

El pipeline se ejecuta automáticamente en las siguientes situaciones:
- Push a la rama `main`.
- Pull request a la rama `main`.

### Ejemplo de Ejecución Manual

Para ejecutar el pipeline manualmente, se puede realizar un push a la rama `main` o crear un pull request a la misma.

---
