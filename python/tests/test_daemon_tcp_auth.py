import asyncio
import json

from core.daemon_server import authenticated


def run(coro):
    return asyncio.run(coro)


async def exchange(token_sent, token_expected="s3cret"):
    seen = []

    async def handler(reader, writer):
        seen.append(await reader.readline())
        writer.write(b"ok\n")
        await writer.drain()
        writer.close()

    server = await asyncio.start_server(authenticated(handler, token_expected), "127.0.0.1", 0)
    port = server.sockets[0].getsockname()[1]
    reader, writer = await asyncio.open_connection("127.0.0.1", port)
    writer.write(json.dumps({"auth": token_sent}).encode() + b"\n" + b"hello\n")
    await writer.drain()
    reply = await asyncio.wait_for(reader.readline(), 2)
    writer.close()
    server.close()
    await server.wait_closed()
    return reply, seen


def test_valid_token_reaches_handler():
    reply, seen = run(exchange("s3cret"))
    assert reply == b"ok\n" and seen == [b"hello\n"]


def test_wrong_token_is_dropped_without_reaching_handler():
    reply, seen = run(exchange("nope"))
    assert reply == b"" and seen == []
