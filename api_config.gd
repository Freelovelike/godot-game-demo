extends Node

## 统一的后端 API 地址。开发时把 USE_LOCAL_BACKEND 改成 true 即可。
const USE_LOCAL_BACKEND := false
const LOCAL_API_BASE := "http://127.0.0.1:8082/api/v1"
const REMOTE_API_BASE := "https://qqfarm.freelike.cn/api/v1"

const API_BASE := LOCAL_API_BASE if USE_LOCAL_BACKEND else REMOTE_API_BASE
