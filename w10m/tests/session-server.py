import base64
import hashlib
import socketserver
import struct
import subprocess
import sys
import threading


class Handler(socketserver.BaseRequestHandler):
    def exact(self, count):
        data = b""
        while len(data) < count:
            chunk = self.request.recv(count - len(data))
            if not chunk:
                raise EOFError()
            data += chunk
        return data

    def send(self, data, opcode=2):
        size = len(data)
        header = bytes([0x80 | opcode, size]) if size < 126 else bytes([0x80 | opcode, 126]) + struct.pack(">H", size)
        self.request.sendall(header + data)

    def handle(self):
        try:
            header = b""
            while not header.endswith(b"\r\n\r\n"):
                header += self.exact(1)
                if len(header) > 16384:
                    raise ValueError("oversized handshake")
            fields = dict(line.split(":", 1) for line in header.decode().split("\r\n")[1:] if ":" in line)
            key = next(v.strip() for k, v in fields.items() if k.lower() == "sec-websocket-key")
            accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
            self.request.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n")
            while True:
                first, second = self.exact(2)
                size = second & 127
                if size == 126:
                    size = struct.unpack(">H", self.exact(2))[0]
                elif size == 127:
                    size = struct.unpack(">Q", self.exact(8))[0]
                if size > 65536:
                    raise ValueError("oversized frame")
                mask = self.exact(4) if second & 128 else None
                payload = self.exact(size)
                if mask:
                    payload = bytes(v ^ mask[i % 4] for i, v in enumerate(payload))
                opcode = first & 15
                if opcode == 8:
                    self.send(payload, 8)
                    return
                if opcode == 9:
                    self.send(payload, 10)
                    continue
                if opcode != 2:
                    continue
                request = struct.unpack(">H", payload[4:6])[0]
                if request in (1, 87):
                    continue
                if request == 6:
                    body = b"\x81\xa9callsSeed\x07"
                    response = payload[:1] + b"\x01" + payload[2:6] + b"\x00" + len(body).to_bytes(3, "big") + body
                else:
                    response = payload[:1] + b"\x01" + payload[2:]
                self.send(response)
        except (EOFError, ConnectionError):
            pass


if __name__ == "__main__":
    with socketserver.ThreadingTCPServer(("127.0.0.1", 0), Handler) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        result = subprocess.run([sys.argv[1], f"ws://127.0.0.1:{server.server_address[1]}/test"], check=False)
        server.shutdown()
        sys.exit(result.returncode)
