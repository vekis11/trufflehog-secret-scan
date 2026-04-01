variable "project_name" {
  type        = string
  description = "Prefix for Docker resource names."
  default     = "trufflehog-demo"
}

variable "nginx_port" {
  type        = number
  description = "Host port published for Nginx."
  default     = 8080
}
