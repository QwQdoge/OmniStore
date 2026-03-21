# pacman.py 重构 - 包信息格式标准化

## 概述
已将 pacman.py 中的包信息输出格式标准化为统一的 JSON 结构，便于后端 API 统一处理。

## 标准化格式

所有返回包信息的函数现在都使用以下统一格式：

```json
{
  "name": "package-name",
  "version": "1.0.0-1",
  "description": "Package description",
  "source": "repository-name",
  "installed": false
}
```

### 字段说明
- **name** (string): 包名
- **version** (string): 版本号（包括 Arch 版本标识）
- **description** (string): 包描述文本
- **source** (string): 来源或仓库名称（如 aur, extra, community 等）
- **installed** (boolean): 包是否已安装

## 修改的函数

### 1. `_create_package_info()` - 新增辅助函数
```python
def _create_package_info(name: str, version: str, description: str = "", 
                        source: str = "", installed: bool = False) -> Dict[str, Any]
```
创建标准化的包信息对象。

### 2. `search(words: str)` - 已更新
- **之前**: 返回 `{'repository': ..., 'name': ..., 'version': ..., 'description': ...}`
- **现在**: 返回标准化格式，`repository` 改为 `source`，添加 `installed` 字段

**示例**:
```python
result = search("chrome")
# 返回:
# {
#   "google-chrome": {
#     "name": "google-chrome",
#     "version": "122.0.6261.94-1",
#     "description": "The web browser from Google",
#     "source": "aur",
#     "installed": false
#   }
# }
```

### 3. `map_available_packages()` - 已更新
- **之前**: 返回 `{'v': version, 'r': repository, 'i': installed}`
- **现在**: 返回完整的标准化包信息

**示例**:
```python
result = map_available_packages()
# 返回:
# {
#   "base": {
#     "name": "base",
#     "version": "3-1",
#     "description": "",
#     "source": "core",
#     "installed": true
#   }
# }
```

### 4. `map_installed()` - 已更新
- **之前**: 返回 `{'package_name': 'version'}`
- **现在**: 返回完整的标准化包信息

**示例**:
```python
result = map_installed()
# 返回:
# {
#   "vim": {
#     "name": "vim",
#     "version": "9.0.1234-1",
#     "description": "",
#     "source": "",
#     "installed": true
#   }
# }
```

## 后向兼容性

- 其他主要函数如 `list_download_data()`, `map_updates_data()` 等保持原有格式，以维护与现有代码的兼容性
- 如果需要这些函数也返回标准化格式，可以在后续根据需要进行更新

## 测试

运行测试脚本验证格式:
```bash
python3 /home/shekong/Projects/OmniArch/test_package_format.py
```

输出应显示:
```
标准化包信息格式:
{
  "name": "google-chrome",
  "version": "122.0.6261.94-1",
  "description": "The web browser from Google",
  "source": "aur",
  "installed": false
}

✅ 格式验证通过!
```

## 前端集成

前端可以期望以下格式的包数据响应：

```javascript
// 来自搜索 API
GET /api/packages/search?query=chrome
Response:
{
  "google-chrome": {
    "name": "google-chrome",
    "version": "122.0.6261.94-1", 
    "description": "The web browser from Google",
    "source": "aur",
    "installed": false
  }
}

// 来自已安装包 API  
GET /api/packages/installed
Response:
{
  "vim": {
    "name": "vim",
    "version": "9.0.1234-1",
    "description": "",
    "source": "",
    "installed": true
  }
}
```

## 优势

1. ✅ **一致性**: 所有包信息使用相同的结构
2. ✅ **易于使用**: 前后端可以使用统一的数据结构
3. ✅ **扩展性**: 新字段可轻松添加到标准格式中
4. ✅ **类型安全**: 明确的字段和类型定义
5. ✅ **API 友好**: JSON 格式适合 REST API 返回
