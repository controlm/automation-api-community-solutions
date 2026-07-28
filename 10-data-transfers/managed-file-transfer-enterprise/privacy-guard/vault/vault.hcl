storage "file" {
  path = "/vault/data"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"   # Traefik terminates TLS at the edge
}
ui = true
