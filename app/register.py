import asyncio
import json
import socket
import ssl

import lz4.block
import msgpack


class MiniSocketClient:
    def __init__(self, host, port, ssl_context=None, ping_interval=30):
        self.host = host
        self.port = port
        self.ssl_context = ssl_context or ssl.create_default_context()
        self._socket = None
        self._seq = 0
        self._pending = {}
        self.is_connected = False
        self.ping_interval = ping_interval
        self._recv_task = None
        self._ping_task = None

    async def connect(self):
        loop = asyncio.get_running_loop()
        raw_sock = await loop.run_in_executor(
            None, lambda: socket.create_connection((self.host, self.port))
        )
        self._socket = self.ssl_context.wrap_socket(raw_sock, server_hostname=self.host)
        self.is_connected = True
        self._recv_task = asyncio.create_task(self._recv_loop())
        self._ping_task = asyncio.create_task(self._ping_loop())

    def _pack_packet(self, ver, cmd, seq, opcode, payload):
        ver_b = ver.to_bytes(1, "big")
        cmd_b = cmd.to_bytes(2, "big")
        seq_b = seq.to_bytes(1, "big")
        opcode_b = opcode.to_bytes(2, "big")
        payload_bytes = msgpack.packb(payload)
        payload_len = len(payload_bytes) & 0xFFFFFF
        payload_len_b = payload_len.to_bytes(4, "big")
        return ver_b + cmd_b + seq_b + opcode_b + payload_len_b + payload_bytes

    def _unpack_packet(self, data):
        payload_len = int.from_bytes(data[6:10], "big") & 0xFFFFFF
        payload_bytes = data[10 : 10 + payload_len]
        if payload_bytes:
            try:
                payload_bytes = lz4.block.decompress(
                    payload_bytes, uncompressed_size=99999
                )
            except lz4.block.LZ4BlockError:
                pass
            payload = msgpack.unpackb(payload_bytes, raw=False, strict_map_key=False)
        else:
            payload = None
        return payload

    async def send_msg(self, opcode: int, payload: dict):
        if not self.is_connected:
            raise RuntimeError("Socket not connected")
        self._seq += 1
        seq = self._seq
        packet = self._pack_packet(
            ver=10, cmd=0, seq=seq, opcode=opcode, payload=payload
        )
        fut = asyncio.get_running_loop().create_future()
        self._pending[seq] = fut
        await asyncio.get_running_loop().run_in_executor(
            None, lambda: self._socket.sendall(packet)
        )
        return await fut

    async def _recv_loop(self):
        loop = asyncio.get_running_loop()

        def _recv_exactly(n):
            buf = bytearray()
            while len(buf) < n:
                chunk = self._socket.recv(n - len(buf))
                if not chunk:
                    return bytes(buf)
                buf.extend(chunk)
            return bytes(buf)

        while self.is_connected:
            try:
                header = await loop.run_in_executor(None, lambda: _recv_exactly(10))
                if not header:
                    self.is_connected = False
                    break
                payload_len = int.from_bytes(header[6:10], "big") & 0xFFFFFF
                payload_bytes = await loop.run_in_executor(
                    None, lambda: _recv_exactly(payload_len)
                )
                payload = self._unpack_packet(header + payload_bytes)
                seq = int.from_bytes(header[3:4], "big")
                fut = self._pending.pop(seq, None)
                if fut and not fut.done():
                    fut.set_result(payload)
            except Exception as e:
                print("Recv loop error:", e)
                await asyncio.sleep(1)

    async def _ping_loop(self):
        while self.is_connected:
            try:
                await self.send_msg(opcode=1, payload={})
            except Exception as e:
                print("Ping failed:", e)
            await asyncio.sleep(self.ping_interval)

    def close(self):
        """Gracefully stop background tasks and close the socket."""
        self.is_connected = False
        try:
            if self._socket:
                try:
                    self._socket.shutdown(socket.SHUT_RDWR)
                except Exception:
                    pass
                try:
                    self._socket.close()
                except Exception:
                    pass
        finally:
            if self._recv_task:
                try:
                    self._recv_task.cancel()
                except Exception:
                    pass
            if self._ping_task:
                try:
                    self._ping_task.cancel()
                except Exception:
                    pass


async def main(phone_number: str):
    client = MiniSocketClient("api.oneme.ru", 443)
    await client.connect()
    h_json = {
        "mt_instanceid": "63ae21a8-2417-484d-849b-0ae464a7b352",
        "userAgent": {
            "deviceType": "ANDROID",
            "appVersion": "25.14.2",
            "osVersion": "Android 14",
            "timezone": "Europe/Moscow",
            "screen": "440dpi 440dpi 1080x2072",
            "pushDeviceType": "GCM",
            "arch": "x86_64",
            "locale": "ru",
            "buildNumber": 6442,
            "deviceName": "unknown Android SDK built for x86_64",
            "deviceLocale": "en",
        },
        "clientSessionId": 8,
        "deviceId": "d53058ab998c3bdd",
    }
    response = await client.send_msg(opcode=6, payload=h_json)
    print(json.dumps(response, indent=4, ensure_ascii=False))
    err = response.get("payload", {}).get("error")
    if err:
        print("Error:", err)

    sa_json = {"type": "START_AUTH", "phone": phone_number}

    response = await client.send_msg(opcode=17, payload=sa_json)
    print(json.dumps(response, indent=4, ensure_ascii=False))
    err = response.get("payload", {}).get("error")
    if err:
        print("Error:", err)

    # token may appear in payload or at the top level, handle both
    payload = response.get("payload") or {}
    temp_token = payload.get("token") or response.get("token")
    if not temp_token:
        print(
            "No auth token returned in response",
            json.dumps(response, indent=4, ensure_ascii=False),
        )
        return
    code = await asyncio.get_running_loop().run_in_executor(
        None, input, "Enter verification code: "
    )
    sc_json = {
        "verifyCode": code,
        "token": temp_token,
        "authTokenType": "CHECK_CODE",
    }
    response = await client.send_msg(opcode=18, payload=sc_json)
    print(json.dumps(response, indent=4, ensure_ascii=False))

    err = response.get("payload", {}).get("error")
    if err:
        print("Error:", err)
    token_src = response.get("payload") or response
    reg_token = token_src.get("tokenAttrs", {}).get("REGISTER", {}).get("token")
    if not reg_token:
        print(
            "No register token returned in response",
            json.dumps(response, indent=4, ensure_ascii=False),
        )
        return
    print("Registering with token:", reg_token)
    rg_json = {
        "lastName": "G",
        "token": reg_token,
        "firstName": "Kirill",
        "tokenType": "REGISTER",
    }
    response = await client.send_msg(opcode=23, payload=rg_json)
    err = response.get("payload", {}).get("error")
    if err:
        print("Error:", err)
    print(json.dumps(response, indent=4, ensure_ascii=False))
    print(response.get("payload", {}).get("token") or response.get("token"))

    client.close()
    await asyncio.sleep(0.1)
    print("Done, connection closed")
    return


asyncio.run(main("+79230556736"))
