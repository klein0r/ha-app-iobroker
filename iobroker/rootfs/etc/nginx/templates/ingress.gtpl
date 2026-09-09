server {
    listen {{ .interface }}:{{ .port }};

    include /etc/nginx/includes/server_params.conf;

    # Entry document: the only response that carries the per-session socketPath.
    # Kept separate so the hashed assets below stay normally cacheable.
    location = / {
        include /etc/nginx/includes/ingress_backend.conf;
        include /etc/nginx/includes/ingress_socketpath.conf;
    }

    location = /index.html {
        include /etc/nginx/includes/ingress_backend.conf;
        include /etc/nginx/includes/ingress_socketpath.conf;
    }

    location / {
        include /etc/nginx/includes/ingress_backend.conf;
    }
}
