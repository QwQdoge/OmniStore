from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from core.search.manager import SearchManager
import json

app = FastAPI()

# 初始化搜索管理器
manager = SearchManager({"aur": True, "flatpak": True, "appimage": True})

@app.get("/")
def read_root():
    return {"status": "OmniArch Backend Running"}

@app.websocket("/ws/search")
async def websocket_search(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # 等待前端发送搜索词，格式如: {"query": "fastfetch"}
            data = await websocket.receive_text()
            request = json.loads(data)
            query = request.get("query")

            if query:
                # 告知前端：搜索开始
                await websocket.send_json({"type": "status", "msg": f"Searching for {query}..."})

                # 获取所有结果并发送
                # 进阶建议：之后我们可以修改 manager 让它支持 yield，实现真正的流式推送
                results = await manager.search_all(query)
                
                await websocket.send_json({
                    "type": "results",
                    "count": len(results),
                    "data": results
                })
    except WebSocketDisconnect:
        print("Client disconnected")
    except Exception as e:
        print(f"WS Error: {e}")