"""Local HTTPS discovery/JWKS fixture for Google's OAuth source validation."""

import json
import ssl
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

documents = {
    "/.well-known/openid-configuration": {
        "issuer": "https://accounts.google.com",
        "authorization_endpoint": "https://accounts.google.com/authorize",
        "token_endpoint": "https://accounts.google.com/token",
        "userinfo_endpoint": "https://accounts.google.com/userinfo",
        "jwks_uri": "https://accounts.google.com/jwks",
        "code_challenge_methods_supported": ["S256"],
    },
    "/jwks": {"keys": []},
}


class DiscoveryHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in documents:
            self.send_error(404)
            return
        body = json.dumps(documents[self.path]).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


server = HTTPServer(("0.0.0.0", 443), DiscoveryHandler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(sys.argv[1], sys.argv[2])
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
