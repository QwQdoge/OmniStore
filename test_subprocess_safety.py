import asyncio
import os
import sys

async def main():
    try:
        proc = await asyncio.create_subprocess_exec("sleep", "100")
        print(f"Started sleep 100 with pid {proc.pid}")
        # Crash the program abruptly
        raise RuntimeError("Oops!")
    except Exception as e:
        print(f"Caught: {e}")
        # Not waiting!

if __name__ == "__main__":
    asyncio.run(main())
