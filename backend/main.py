from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from core.search.manager import SearchManager
from core.executor import InstallExecutor  # ✅ 导入真实的执行器
import json
import asyncio

app = FastAPI()

# 初始化后端核心组件
executor = InstallExecutor()
manager = SearchManager({"aur": True, "flatpak": True, "appimage": True})

@app.get("/")
def read_root():
    return {"status": "OmniArch Backend Running"}

# --- 搜索接口 ---
@app.websocket("/ws/search")
async def websocket_search(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            request = json.loads(data)
            query = request.get("query")

            if query:
                await websocket.send_json({"type": "status", "msg": f"Searching for {query}..."})
                results = await manager.search_all(query)
                
                await websocket.send_json({
                    "type": "results",
                    "count": len(results),
                    "data": results
                })
    except WebSocketDisconnect:
        print("Search Client disconnected")
    except Exception as e:
        print(f"Search WS Error: {e}")

# --- 安装/卸载接口 ---
@app.websocket("/ws/install")
async def websocket_install(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # 1. 接收前端指令，格式如: {"action": "install", "package": {...}}
            data = await websocket.receive_text()
            request = json.loads(data)
            
            action = request.get("action") # "install" 或 "uninstall"
            package = request.get("package")

            if action == "install" and package:
                # ✅ 传入 websocket.send_text 作为回调，实现日志实时推送
                await executor.install(package, callback=websocket.send_text)
                await websocket.send_text("[Status] Task Finished")
            
            elif action == "uninstall" and package:
                await executor.uninstall(package, callback=websocket.send_text)
                await websocket.send_text("[Status] Task Finished")
                
    except WebSocketDisconnect:
        print("Install Client disconnected")
    except Exception as e:
        print(f"Install WS Error: {e}")
        try:
            await websocket.send_text(f"❌ Error: {str(e)}")
        except:
            pass

    # executor.py 核心逻辑参考
    async def install(self, package, callback):
    # 假设 package 是 {"name": "vlc", "source": "AUR"}
        process = await asyncio.create_subprocess_exec(
        'yay', '-S', '--noconfirm', package['name'],
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT
        )
        # 确保 stdout 不为 None 
        if process.stdout:
            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                # 解码并回传
                await callback(line.decode().strip())