locals {
  network_name = "${var.project_name}-net"
  app_image    = "${var.project_name}-app:latest"
}

resource "docker_network" "app" {
  name = local.network_name
}

resource "docker_image" "app" {
  name = local.app_image
  build {
    context    = abspath("${path.module}/../app")
    dockerfile = "Dockerfile"
  }
  triggers = {
    dockerfile = filemd5(abspath("${path.module}/../app/Dockerfile"))
    main_py    = filemd5(abspath("${path.module}/../app/main.py"))
    req        = filemd5(abspath("${path.module}/../app/requirements.txt"))
  }
}

resource "docker_container" "app" {
  name  = "${var.project_name}-app"
  image = docker_image.app.image_id

  networks_advanced {
    name    = docker_network.app.name
    aliases = ["app"]
  }

  healthcheck {
    test         = ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"]
    interval     = "10s"
    timeout      = "3s"
    retries      = 3
    start_period = "5s"
  }
}

resource "docker_container" "nginx" {
  name  = "${var.project_name}-nginx"
  image = "nginx:1.27-alpine"

  ports {
    internal = 80
    external = var.nginx_port
  }

  volumes {
    host_path      = abspath("${path.module}/../nginx/default.conf")
    container_path = "/etc/nginx/conf.d/default.conf"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.app.name
  }

  depends_on = [docker_container.app]
}
