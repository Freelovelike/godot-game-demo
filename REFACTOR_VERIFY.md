# 重构验证记录

本文记录按 `REFACTOR_PLAN.md` 推进后的验证状态，方便后续 Codex 或开发者继续检查。

## 当前静态验证

- `git diff --check` 通过。
- UTF-8 检查通过：`REFACTOR_PLAN.md`、`resources/farm/default_catalog.tres`、`scripts/farm/farm_state.gd`。
- 未修改 `project.godot`、`Login.tscn`、`login.gd`、`api_config.gd`、`assets/`、`scripts/plot_anchor_tile.gd`。
- `Farm.tscn` 中 `PlotAnchors` 改挂到 `WorldRoot` 下，但 `PlotAnchors` 自身 `position = Vector2(143, 55)` 未改变。
- `Farm.tscn` 中 30 个 `Plot_*` 地块的 `position` 行保留原值。
- `Farm.tscn` 新增 `WorldRoot` 和 `Systems`，`UILayer` 仍直接位于 `Farm` 下。
- `Farm.tscn` 中 `unique_id` 数量为 132，未发现重复。
- `Farm.tscn` 和 `resources/farm/default_catalog.tres` 中声明的 `res://` 外部资源路径均存在。
- 动态创建的 `FarmApiClient`、`Camera2D`、`CameraController` 挂到 `Systems`，并显式命名。
- `CameraController` 不再通过父节点查找 `Background`，改由 `farm.gd` 传入 `WorldRoot/Background`。
- 农场后端接口路径仍为 `/farm/config`、`/farm/load`、`/farm/save`、`/farm/action`、`/farm/sell`。
- `FarmApiClient` 请求前会确保内部 `HTTPRequest` 已初始化，避免节点 `_ready()` 时序导致空引用。
- 本地 fallback 数据位于 `resources/farm/default_catalog.tres`，顺序保持为原 `DEFAULT_CROPS` 和 `DEFAULT_FERTILIZERS` 顺序。
- `resources/farm/default_catalog.tres` 包含 9 个作物定义和 7 个肥料定义，作物顺序为生菜、辣椒、茄子、西红柿、草莓、玉米、向日葵、南瓜、西瓜。
- 未发现重复 `class_name`。
- 已修正 `FarmState._apply_plots()` 中 `plot_index / cols` 到 `int` 的显式转换，降低 Godot 4 静态类型解析风险。
- `ShopOverlay`、`InventoryOverlay`、`FarmRenderer` 的作物颜色读取已增加 fallback，避免远程配置作物数量超过本地颜色表时直接数组越界；现有 9 个作物颜色不变。
- 未发现剩余 `CROP_COLORS[i][j]` 形式的直接颜色数组访问。
- `FarmRules`、`farm.gd` 的上下文菜单入口和上下文菜单动作执行已增加负坐标/非法菜单项保护，避免异常输入触发负索引数组访问。
- `ShopOverlay`、`InventoryOverlay` 的 catalog fallback 读取已增加负 id 保护，避免 `CROPS[-1]` 或 `FERTILIZERS[-1]` 访问。
- `FarmRenderer` 读取的 `render_ctx` key 与 `farm.gd:_build_render_context()` 输出 key 已做静态比对，未发现漏传字段。
- 当前环境未找到 `godot`、`godot4` 或 `godot4.6` 命令，尚未完成编辑器运行验证。

## Godot Editor 手动验证清单

1. 用 Godot 4.6+ 打开项目，确认没有脚本解析错误。
2. 启动默认主场景 `Login.tscn`，验证登录后能进入农场。
3. 如需开发直进，临时将 `project.godot` 的 `run/main_scene` 改成 `res://Farm.tscn`，验证完成后还原。
4. 验证农场背景、地块、作物、成熟标签、进度条、虫草水图标、tooltip 显示正常。
5. 验证相机平移和缩放后，地块点击坐标仍正确。
6. 验证商店、背包、设置、toast、确认弹窗能正常打开和关闭。
7. 验证开垦、选种、种植、浇水、施肥、除虫、除草、收获、铲除、出售主流程。
8. 验证无远程配置或 `/farm/config` 失败时，本地 `default_catalog.tres` fallback 能展示作物和肥料。
9. 验证 `/farm/config` 成功时，仍以服务端作物和肥料配置为准。
10. 验证云端加载和保存 payload 未破坏存档兼容。

## 重点回归点

- `CROPS` 下标和 crop_id 语义不能改变。
- `PlotAnchors` 及子地块坐标不能改变。
- API endpoint 和 payload 不能改变。
- 服务端仍是游戏状态权威，客户端只保留状态镜像、输入、渲染和 UI。
