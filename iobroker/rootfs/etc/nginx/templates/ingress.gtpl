server {
    listen {{ .interface }}:{{ .port }};

    include /etc/nginx/includes/server_params.conf;
    include /etc/nginx/includes/proxy_params.conf;

    location / {
        allow   172.30.32.2;
        deny    all;

        proxy_pass http://backend;

        # ioBroker.admin >= 8.0.7 builds the WebSocket URL as
        # `<protocol>://<host>:<port>` + `window.socketPath`. That value comes from the
        # admin instance's static reverse-proxy table, which cannot hold HA's ingress
        # prefix because the session token in it changes. Without it the browser dials
        # `ws://<ha-host>:8123/?sid=...` instead of the ingress path and the handshake
        # fails. The Supervisor passes the real prefix in X-Ingress-Path, so patch the
        # value into the served HTML on the way out.
        sub_filter_once   on;
        sub_filter_types  text/html;
        sub_filter        "window.socketPath = '';" "window.socketPath = '$http_x_ingress_path/';";
    }
}
