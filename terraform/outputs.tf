output "nginx_url" {
  value       = "http://localhost:${var.nginx_port}"
  description = "Hit /health through Nginx."
}

output "app_container" {
  value       = docker_container.app.name
  description = "FastAPI container name."
}
