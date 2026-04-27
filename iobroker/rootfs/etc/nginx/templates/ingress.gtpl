server {
    listen {{ .interface }}:{{ .port }};

    include /etc/nginx/includes/server_params.conf;
    include /etc/nginx/includes/proxy_params.conf;

    # ioBroker admin 7.x uses a raw WebSocket (iob-protocol) that constructs
    # its URL from window.location.host with path "/" — ignoring the HA Ingress
    # sub-path. Injecting socketUrl redirects the WebSocket directly to the
    # exposed admin port (8081), bypassing the Ingress proxy for the WS leg.
    sub_filter_once on;
    sub_filter_types text/html;
    sub_filter '</head>' '<script>window.socketUrl=location.protocol+"//"+location.hostname+":8081/";</script></head>';

    location / {
        allow   172.30.32.2;
        deny    all;

        # Buffering must be on for sub_filter to rewrite the HTML body.
        # WebSocket upgrades are handled by nginx in stream mode regardless.
        proxy_buffering on;

        proxy_pass http://backend;
    }
}
