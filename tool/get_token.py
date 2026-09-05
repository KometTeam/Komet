#!/usr/bin/env python3
"""Komet login-token grabber.

Подключается к серверу MAX (api2.oneme.ru), делает handshake, запрашивает код
на номер (SMS/пуш в MAX), спрашивает код в консоли, проверяет и печатает
login-токен. Этот токен — то, что ложится в KOMET_REVIEW_PAYLOAD для store-сборки.

    python3 tool/get_token.py +7XXXXXXXXXX

Зависимости: pip install msgpack zstandard
(lz4 нужен, только если сервер вдруг ответит LZ4-frame — обычно нет.)

Никакого нативного ядра: весь провод (10-байтный заголовок, MessagePack,
LZ4/Zstd) сделан здесь на сокете. Реализация повторяет kolibri-net.
"""

import argparse
import hashlib
import os
import socket
import ssl
import struct
import sys

try:
    import msgpack
except ImportError:
    sys.exit("нет msgpack — установи: pip install msgpack")

DEFAULT_HOST = "api2.oneme.ru"
DEFAULT_PORT = 443
CA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mincifry_ca.pem")

SESSION_INIT = 6
AUTH_REQUEST = 17
AUTH = 18

PROTOCOL_VERSION = 10
CMD_REQUEST = 0
CMD_OK = 1
CMD_NOT_FOUND = 2
CMD_ERROR = 3
HEADER_SIZE = 10

DEVICE_ID = "kolibri-rs-device"
INSTANCE_ID = "kolibri-rs-instance"
CLIENT_SESSION_ID = 1_700_000_000

USER_AGENT = {
    "deviceType": "ANDROID",
    "appVersion": "26.20.2",
    "osVersion": "Android 14",
    "timezone": "Europe/Moscow",
    "screen": "420dpi 420dpi 1080x2340",
    "pushDeviceType": "GCM",
    "arch": "arm64-v8a",
    "locale": "ru",
    "buildNumber": 6758,
    "deviceName": "Rust",
    "deviceLocale": "ru",
}

SIGNATURE_DIGEST = bytes.fromhex(
    "1684414033eb263e2c615f8b7df5ed8793850a07656304997fbf07e9e21e1e93"
)
DEX_DIGEST = bytes.fromhex(
    "0a6265f6e5d8231b9cba641f8c40475e6f3baeb06ed41b804b9bf7307aa4214e"
)
SO_DIGEST = bytes.fromhex(
    "90e2fb8745b17b42a10182f8d8ac590e3fca5b311e2ce2d5144fa2c18cb3090d"
)


def auth_mode(calls_seed, device_id):
    seed = struct.pack(">q", calls_seed)
    dev = device_id.encode("utf-8")
    out = bytearray()
    for digest in (SIGNATURE_DIGEST, DEX_DIGEST, SO_DIGEST):
        h = hashlib.sha256()
        h.update(digest)
        h.update(seed)
        h.update(dev)
        out += h.digest()
    return bytes(out)


def lz4_block_decompress(src, max_size=32 * 1024 * 1024):
    out = bytearray()
    pos = 0
    n = len(src)
    while pos < n:
        token = src[pos]
        pos += 1
        lit_len = token >> 4
        if lit_len == 15:
            while pos < n:
                b = src[pos]
                pos += 1
                lit_len += b
                if b != 255:
                    break
        if lit_len:
            if len(out) + lit_len > max_size:
                raise ValueError("lz4: decompressed size over limit")
            if pos + lit_len > n:
                raise ValueError("lz4: truncated literals")
            out += src[pos : pos + lit_len]
            pos += lit_len
        if pos >= n:
            break
        if pos + 1 >= n:
            raise ValueError("lz4: truncated match offset")
        offset = src[pos] | (src[pos + 1] << 8)
        pos += 2
        if offset == 0:
            raise ValueError("lz4: zero match offset")
        match_len = (token & 0x0F) + 4
        if (token & 0x0F) == 0x0F:
            while pos < n:
                b = src[pos]
                pos += 1
                match_len += b
                if b != 255:
                    break
        if len(out) + match_len > max_size:
            raise ValueError("lz4: decompressed size over limit")
        if offset > len(out):
            raise ValueError("lz4: match offset before start")
        start = len(out) - offset
        for i in range(match_len):
            out.append(out[start + i])
    return bytes(out)


def decompress(src):
    if len(src) >= 4 and src[0] == 0x28 and src[1] == 0xB5 and src[2] == 0x2F and src[3] == 0xFD:
        import zstandard

        return zstandard.ZstdDecompressor().stream_reader(_BytesIO(src)).read()
    if len(src) >= 4 and src[0] == 0x04 and src[1] == 0x22 and src[2] == 0x4D and src[3] == 0x18:
        try:
            import lz4.frame
        except ImportError:
            sys.exit("сервер прислал LZ4-frame — установи: pip install lz4")
        return lz4.frame.decompress(src)
    return lz4_block_decompress(src)


def _BytesIO(data):
    import io

    return io.BytesIO(data)


def encode_packet(opcode, payload_obj, seq):
    body = msgpack.packb(payload_obj, use_bin_type=True)
    header = bytearray()
    header.append(PROTOCOL_VERSION)
    header.append(CMD_REQUEST)
    header += struct.pack(">H", seq)
    header += struct.pack(">H", opcode)
    packed_len = (0 << 24) | (len(body) & 0x00FFFFFF)
    header += struct.pack(">I", packed_len)
    return bytes(header) + body


def read_exactly(sock, count):
    buf = bytearray()
    while len(buf) < count:
        chunk = sock.recv(count - len(buf))
        if not chunk:
            raise ConnectionError("соединение закрыто сервером")
        buf += chunk
    return bytes(buf)


def read_packet(sock):
    header = read_exactly(sock, HEADER_SIZE)
    cmd = header[1]
    seq = struct.unpack(">H", header[2:4])[0]
    opcode = struct.unpack(">H", header[4:6])[0]
    packed_len = struct.unpack(">I", header[6:10])[0]
    comp_flag = packed_len >> 24
    payload_len = packed_len & 0x00FFFFFF
    payload = read_exactly(sock, payload_len) if payload_len else b""
    if payload and comp_flag:
        payload = decompress(payload)
    value = msgpack.unpackb(payload, raw=False) if payload else None
    return cmd, seq, opcode, value


def request(sock, opcode, payload_obj, seq):
    sock.sendall(encode_packet(opcode, payload_obj, seq))
    while True:
        cmd, rseq, _opcode, value = read_packet(sock)
        if rseq != seq:
            continue
        if cmd == CMD_ERROR:
            raise RuntimeError(server_error_text(value))
        if cmd == CMD_NOT_FOUND:
            raise RuntimeError("сервер: not found")
        return value


def server_error_text(payload):
    if isinstance(payload, dict):
        for key in ("localizedMessage", "title", "message"):
            v = payload.get(key)
            if isinstance(v, str) and v.strip():
                return f"ошибка сервера: {v.strip()}"
    return f"ошибка сервера: {payload!r}"


def connect(host, port, insecure):
    if insecure:
        ctx = ssl._create_unverified_context()
    else:
        if not os.path.exists(CA_FILE):
            sys.exit(f"нет файла CA {CA_FILE} — положи рядом mincifry_ca.pem или запусти с --insecure")
        ctx = ssl.create_default_context(cafile=CA_FILE)
    raw = socket.create_connection((host, port), timeout=30)
    sock = ctx.wrap_socket(raw, server_hostname=host)
    sock.settimeout(30)
    return sock


def extract_login_token(result):
    attrs = result.get("tokenAttrs") if isinstance(result, dict) else None
    attrs = attrs if isinstance(attrs, dict) else {}
    login = attrs.get("LOGIN")
    if isinstance(login, dict) and isinstance(login.get("token"), str):
        return login["token"], "LOGIN"
    register = attrs.get("REGISTER")
    if isinstance(register, dict) and isinstance(register.get("token"), str):
        return register["token"], "REGISTER"
    return None, None


def main():
    ap = argparse.ArgumentParser(description="Komet: получить login-токен по номеру и коду")
    ap.add_argument("phone", nargs="?", help="номер, напр. +79991234567")
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--insecure", action="store_true", help="не проверять TLS-сертификат")
    args = ap.parse_args()

    phone = args.phone or input("Номер телефона (+7...): ").strip()
    digits = "".join(c for c in phone if c.isdigit())
    if not digits:
        sys.exit("пустой номер")
    phone = "+" + digits

    sock = connect(args.host, args.port, args.insecure)
    seq = 0
    try:
        seq += 1
        handshake = {
            "mt_instanceid": INSTANCE_ID,
            "userAgent": USER_AGENT,
            "clientSessionId": CLIENT_SESSION_ID,
            "deviceId": DEVICE_ID,
        }
        info = request(sock, SESSION_INIT, handshake, seq)
        calls_seed = info.get("callsSeed") if isinstance(info, dict) else None
        if calls_seed is None:
            sys.exit(f"handshake без callsSeed: {info!r}")
        print(f"[+] онлайн, callsSeed={calls_seed}")

        seq += 1
        req = {
            "phone": phone,
            "type": "START_AUTH",
            "language": "ru",
            "mode": auth_mode(calls_seed, DEVICE_ID),
        }
        resp = request(sock, AUTH_REQUEST, req, seq)
        token = resp.get("token") if isinstance(resp, dict) else None
        if not token:
            sys.exit(f"authRequest без token: {resp!r}")
        print(f"[+] код отправлен на {phone}")

        code = input("Введи код из SMS/MAX: ").strip()
        code = "".join(c for c in code if c.isdigit())

        seq += 1
        verify = {"token": token, "verifyCode": code, "authTokenType": "CHECK_CODE"}
        result = request(sock, AUTH, verify, seq)

        if isinstance(result, dict) and result.get("passwordChallenge") is not None:
            sys.exit("[-] на аккаунте включена 2FA — этот скрипт её не проходит. Отключи 2FA или заведи демо-аккаунт без неё.")

        login_token, kind = extract_login_token(result)
        if not login_token:
            sys.exit(f"[-] не нашёл токен в ответе: keys={list(result) if isinstance(result, dict) else result!r}")

        if kind == "REGISTER":
            print("[!] это НОВЫЙ аккаунт (регистрация не завершена). Токен ниже — регистрационный, не login.")

        print()
        print("=" * 60)
        print("LOGIN TOKEN:")
        print(login_token)
        print("=" * 60)
        print()
        print("Дальше собери payload для ревьювера:")
        print(f"  printf '{{\"token\":\"{login_token}\"}}' | \\")
        print("    cargo run -q --manifest-path native/komet_crypto/rust/Cargo.toml \\")
        print("    --features blobtool --bin review_blob -- '<номер>' '<код>'")
    finally:
        try:
            sock.close()
        except OSError:
            pass


if __name__ == "__main__":
    main()
