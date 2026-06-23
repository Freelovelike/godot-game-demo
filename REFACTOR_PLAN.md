# Godot 农场项目渐进式重构计划

## 项目现状

本项目是 Godot 4.6 的 2.5D 等距农场游戏。当前入口为 `Login.tscn`，登录后进入 `Farm.tscn`。游戏主要逻辑集中在根目录 `farm.gd`，包括农场状态、输入处理、服务端请求、保存加载、地块操作、上下文菜单、世界绘制辅助方法和 UI 状态编排。

项目已经有一些拆分基础：

- `scenes/farm_api.gd` 负责农场相关 HTTP 请求。
- `scenes/farm_renderer.gd` 负责部分世界绘制流程。
- `scenes/ui_overlay.gd`、`shop_overlay.gd`、`inventory_overlay.gd`、`settings_overlay.gd` 负责部分 UI。
- `scripts/crop_atlas.gd` 管理作物贴图。
- `Farm.tscn` 中的 `PlotAnchors` 定义 30 块地的等距坐标。

当前主要架构问题是 `farm.gd` 仍然承担过多职责，其他模块虽然存在，但大多依赖 `farm_ref` 直接读取或调用 `farm.gd` 内部字段和方法，耦合仍然较高。

## 重构目标

重构目标是逐步把 `farm.gd` 从“所有逻辑都在一个脚本里”的神对象，收敛为农场场景控制器，让它主要负责协调状态、输入、API、渲染和 UI。

核心原则：

- 服务端继续作为游戏状态权威。
- 客户端只维护状态镜像、输入、渲染和 UI。
- 不改变当前后端接口路径和 payload。
- 不改变 `CROPS` 顺序语义，避免破坏存档兼容。
- 不移动 `PlotAnchors` 布局，避免破坏等距地块坐标。
- 每阶段只做一个架构方向的改动。
- 每阶段完成后用 Godot 手动验证主流程。

## 不做事项

本轮重构计划不包含以下内容：

- 不重写整套游戏逻辑。
- 不替换 Godot UI 技术栈。
- 不改变登录、注册、鉴权接口。
- 不改变 `/farm/config`、`/farm/load`、`/farm/action`、`/farm/save`、`/farm/sell` 的协议。
- 不调整作物 ID 和 `CROPS` 数组顺序。
- 不重排 `Farm.tscn` 中 `PlotAnchors` 的位置。
- 不引入大型框架或复杂 ECS。
- 不一次性把所有 `Dictionary` 状态改成强类型对象。

## 分阶段计划

### 阶段 0：建立验证基准

目标：在任何代码重构前，明确“当前行为正确”的验证方式。

执行内容：

- 记录当前主场景启动方式：默认 `Login.tscn`，开发时可临时切到 `Farm.tscn`。
- 记录当前主流程：登录、加载农场、开垦、选择种子、种植、浇水、施肥、收获、铲除、出售。
- 保留或更新一张主场景截图，用于视觉对比。
- 确认当前项目没有 CLI 测试流程，主要依赖 Godot Editor 手动验证。

完成标准：

- 后续每个阶段都能按同一套主流程验证。
- 若某阶段出现行为变化，可以快速判断是否为重构引入。

### 阶段 1：整理 API 层

目标：让 HTTP 请求细节集中在 API 客户端，`farm.gd` 只关心业务动作结果。

执行内容：

- 保留 `scenes/farm_api.gd` 的现有行为，先只整理命名、职责和注释。
- 后续可迁移为 `scripts/farm/farm_api_client.gd`，但迁移时必须同步更新 preload 路径。
- API 客户端继续提供 `request_config()`、`request_load()`、`request_save()`、`request_action()`、`request_sell()`。
- API 客户端继续通过 signal 返回原始 HTTP result、response_code、headers、body。
- 响应解析和 toast 文案暂时仍留在 `farm.gd`，避免一次改动过大。

完成标准：

- 所有农场接口仍能正常请求。
- `farm.gd` 不直接创建多个 `HTTPRequest`。
- 未改变任何后端 URL、method、headers 或 payload。

### 阶段 2：抽出 Crop/Fertilizer Catalog

目标：减少 `CROPS[i][3]`、`FERTILIZERS[i][2]` 这类魔法下标访问。

执行内容：

- 新增作物目录对象，例如 `scripts/farm/crop_catalog.gd`。
- 新增肥料目录对象，例如 `scripts/farm/fertilizer_catalog.gd`。
- 初期内部仍可保存原数组结构，以保持兼容。
- 对外提供语义化访问方法，例如获取作物名称、种子价格、成长时间、贴图 key、产量范围、单价。
- `_apply_remote_config()` 仍然接收服务端配置，但应用后同步更新 catalog。
- 渲染、UI、tooltip 逐步改为通过 catalog 读字段。

完成标准：

- 新代码不再新增作物魔法下标访问。
- 旧数组顺序仍保留，存档和服务端 crop_id 语义不变。
- 商店、背包、地块 tooltip 的作物信息显示不变。

### 阶段 3：抽出 FarmState

目标：把运行时农场状态从 `farm.gd` 中集中迁出。

执行内容：

- 新增 `scripts/farm/farm_state.gd`。
- 初期可继续使用现有 `Dictionary` 表示地块，避免一次性强类型化。
- 迁移金币、等级、经验、地块数组、背包、肥料背包、游戏时间等状态字段。
- 迁移默认状态初始化逻辑。
- 迁移服务端状态应用逻辑，即当前 `_apply_state()` 的主体。
- 迁移 inventory key 归一化逻辑。
- `farm.gd` 改为通过 `state` 读取和更新状态。

完成标准：

- 服务端返回数据后，由 `FarmState` 应用状态。
- `farm.gd` 仍负责接收 API response、toast 和刷新画面。
- 保存 payload 行为保持不变。
- 加载云端存档后，农场显示、金币、等级、背包数量与重构前一致。

### 阶段 4：抽出 FarmRules

目标：把“点击地块后应该发生什么”的规则从输入代码中剥离。

执行内容：

- 新增 `scripts/farm/farm_rules.gd`。
- 迁移或集中这些纯规则：地块是否解锁、下一块可开垦地、开垦等级、开垦金币、工具模式对应动作、上下文菜单可用项。
- 为地块点击生成意图对象，例如 toast、打开弹窗、打开仓库、发送服务端 action。
- `farm.gd` 的 `_do_tile_action()` 只负责把意图执行出来。

完成标准：

- `_do_tile_action()` 明显变短。
- 工具模式 0-9 的行为保持不变。
- 空地、有作物、未解锁地块的点击反馈保持不变。
- 上下文菜单中的种植、浇水、施肥、除虫、除草、收获、铲除行为保持不变。

### 阶段 5：UI 信号化

目标：降低 UI 对 `farm.gd` 内部字段和私有方法的直接依赖。

执行内容：

- `ui_overlay.gd` 通过 signal 向外发出用户意图，例如选择工具、打开商店、打开背包、打开设置。
- `farm.gd` 监听 UI signal 并执行对应逻辑。
- UI 更新改为由 `farm.gd` 主动传入 view model，例如金币、等级、经验、已解锁土地数量、当前工具、toast 文案。
- `shop_overlay.gd`、`inventory_overlay.gd`、`settings_overlay.gd` 保留现有 signal 风格，并减少直接读写外部状态。

完成标准：

- UI 脚本不再调用 `farm_ref._xxx()` 私有方法。
- 商店、背包、设置、确认弹窗、toast 行为保持不变。
- UI 仍固定在屏幕空间，不受 Camera2D 缩放和平移影响。

### 阶段 6：Renderer 降耦合

目标：让世界渲染只依赖明确传入的渲染上下文，而不是整个 `farm_ref`。

执行内容：

- 将 `FarmRenderer.draw_world(farm_ref)` 逐步改为接收渲染上下文。
- 渲染上下文包含状态、catalog、hover 地块、当前工具、选中种子、选中肥料、必要贴图和绘制接口。
- 逐步把 `_draw_land_tile()`、`_draw_crop_atlas_texture()`、tooltip 绘制等 helper 迁入 renderer 或专门的绘制工具。
- 保持世界绘制仍在 `_draw()` 中触发，避免改变 Godot 渲染生命周期。

完成标准：

- `farm_renderer.gd` 不再随意读取 `farm.gd` 的业务字段。
- 地块、作物、成熟标签、进度条、虫草水图标、tooltip、锁地提示显示不变。
- 摄像机移动和缩放后，世界渲染位置不变形。

### 阶段 7：场景节点结构整理

目标：让 `Farm.tscn` 的节点树更清晰表达系统结构。

执行内容：

- 逐步整理节点为 World、Systems、UI 三类。
- 保持 `PlotAnchors` 节点和其子节点位置不变。
- Camera、API、Interaction、UI 等适合 Node 的系统可显式挂到场景中。
- 纯数据和纯规则仍可保持 `RefCounted`，不强行节点化。

推荐目标结构：

```text
Farm
  WorldRoot
    Background
    PlotAnchors
  Camera2D
  Systems
    FarmApiClient
  UILayer
    UIOverlay
    ShopOverlay
    InventoryOverlay
    SettingsOverlay
```

完成标准：

- 打开 `Farm.tscn` 能从节点树理解主要结构。
- `PlotAnchors` 坐标未发生变化。
- 游戏主流程和画面布局保持不变。

### 阶段 8：数据 Resource 化

目标：在基础结构稳定后，再把作物和肥料配置变成更适合 Godot 编辑器维护的数据资源。

执行内容：

- 新增 `CropDef`、`FertilizerDef` Resource 类型。
- 本地 `.tres` 资源作为编辑器预览和离线 fallback。
- 线上运行仍优先使用 `/farm/config` 返回的服务端配置。
- Resource 字段命名与 catalog 语义保持一致。

完成标准：

- 没有远程配置时，本地 fallback 能正常展示基础作物和肥料。
- 有远程配置时，仍以服务端配置为准。
- 作物贴图、商店信息、tooltip 信息显示正常。

## 每阶段验收标准

每个阶段完成后都必须验证：

- Godot Editor 能打开项目。
- 主场景能启动。
- 登录或开发直进农场流程可用。
- 农场能加载云端状态。
- 商店、背包、设置能打开和关闭。
- 地块点击、种植、浇水、施肥、收获、铲除行为可用。
- toast 和确认弹窗可用。
- 没有无关文件被修改。

如果某阶段无法完整验证，必须在阶段总结中明确说明未验证项和原因。

## 风险与回滚策略

主要风险：

- `CROPS` 下标语义变化导致存档或服务端 crop_id 对不上。
- `PlotAnchors` 坐标变化导致等距格子错位。
- UI 从自绘和 Control 混合状态迁移时出现点击穿透或遮挡。
- Renderer 降耦合时漏传状态，导致 tooltip 或成熟提示不显示。
- API 层调整时误改请求 payload，导致服务端动作失败。

回滚策略：

- 每阶段单独提交或至少单独检查 diff。
- 每阶段只改一个架构方向，避免混合 UI、API、状态和渲染改动。
- 如果验证失败，优先回滚当前阶段，不回滚之前已验证阶段。
- 不在同一阶段同时移动文件和重写逻辑；需要移动时先移动并更新引用，再单独改内部实现。

## 推荐 Codex 执行提示词

执行阶段 1：

```text
按 REFACTOR_PLAN.md 执行阶段 1，只整理 API 层，不改变玩法逻辑、后端接口、payload 或 UI。完成后说明改了哪些文件，以及如何在 Godot 中验证。
```

执行阶段 2：

```text
按 REFACTOR_PLAN.md 执行阶段 2，抽出 Crop/Fertilizer Catalog。保持 CROPS 顺序语义和服务端 crop_id 兼容，不改变显示内容。完成后列出被替换的魔法下标访问和验证步骤。
```

执行阶段 3：

```text
按 REFACTOR_PLAN.md 执行阶段 3，抽出 FarmState。不要改变服务端协议和保存 payload。完成后说明 FarmState 管理哪些字段，以及如何验证云端加载、种植、收获和背包数据。
```

执行阶段 4：

```text
按 REFACTOR_PLAN.md 执行阶段 4，抽出 FarmRules。目标是缩短 _do_tile_action()，保持工具模式 0-9 行为不变。完成后说明每类地块点击意图如何映射到现有动作。
```

执行阶段 5：

```text
按 REFACTOR_PLAN.md 执行阶段 5，做 UI 信号化。UI 不再直接调用 farm_ref 的私有方法，改为发 signal，由 farm.gd 处理。保持所有按钮、弹窗和 toast 行为不变。
```

执行阶段 6：

```text
按 REFACTOR_PLAN.md 执行阶段 6，降低 FarmRenderer 与 farm.gd 的耦合。不要改变画面表现和相机行为。完成后说明 renderer 需要哪些渲染上下文。
```

执行阶段 7：

```text
按 REFACTOR_PLAN.md 执行阶段 7，整理 Farm.tscn 节点结构。不要移动 PlotAnchors 或改变任何地块坐标。完成后说明节点结构变化和验证方式。
```

执行阶段 8：

```text
按 REFACTOR_PLAN.md 执行阶段 8，设计 CropDef/FertilizerDef Resource fallback。线上仍以 /farm/config 为准，不改变服务端配置优先级。完成后说明本地 Resource 只用于编辑器预览和离线 fallback。
```

