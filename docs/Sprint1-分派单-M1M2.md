# Sprint 1 分派单（给 Codex）

> 依据：`docs/营业基础玩法设计规格.md`。本轮只做 **M1 + M2**，做完并 CI 绿后再谈 M3/M4。
> 分支：从 `main`（当前 6b66b32）新建 `feat/dishes-patrons`。

## 目标一句话
把「菜谱」和「顾客口味」从硬编码改成表驱动，实现「有取舍的菜单 + 有因果的口味」，并完成存档 v4→v5 迁移。

## 必改硬编码（都在 hotpot/main.gd）
1. `const BASE=[1,5,2]`、`const SPECIALS=Recipes.NAMES`
2. `tick_table_service` 里 `var mains=[1,2,6]`
3. `const SIDE_FOODS=[0,3,4,5]`
4. `spawn_guest` 里 `wish=1 if ticket%4==2 else ticket%6`
5. `checkout` 里 `liked` / `missed_taste` 由 `ticket%N` 决定的部分

以上全部改为查新增的表（见下）。

## 新增文件

### 1. `hotpot/systems/dishes.gd`（菜谱定义表，`extends RefCounted`）
接口草案（可微调，但字段名保持稳定，供测试和后续 M3/M4 引用）：

```gdscript
extends RefCounted

# 每道菜一个条目
const DISHES = [
  # {id, name, kind, core: [食材id], fill, tags: [口味标签], tier}
  # kind: "main" 主菜 / "side" 自取 / "special" 特别菜
  # tier: "normal" / "signature"
]
# 已解锁菜谱（运行时） — 由 main.gd 持有还是这里持有，二选一并写清

static func by_id(id: int) -> Dictionary
static func mains() -> Array        # 所有 kind=="main" 的 id
static func sides() -> Array        # 所有 kind=="side" 的 id
static func specials() -> Array     # 所有 kind=="special" 的 id
static func is_main(id: int) -> bool
static func is_side(id: int) -> bool
static func is_special(id: int) -> bool
```

约束：
- 现有 3 道特别菜（香煎霜牛 / 清渍酸甜萝卜 / 椒香跳跳虾）**编号与 core 不变**，只是搬进表里；`recipes.gd` 的 `NAMES/CORES/FLAVORS/FORBIDDEN` 与这里不重复定义，择一处为准并注明。
- 普通主菜扩到 6 种（对应 6 种基础食材各一道），自取 4 种。

### 2. `hotpot/systems/patrons.gd`（顾客偏好模板，`extends RefCounted`）
接口草案：

```gdscript
extends RefCounted

# 返回一个顾客偏好档案（营业期临时，不进存档）
static func profile(ticket: int, rng: RandomNumberGenerator) -> Dictionary
# 返回结构：
# {
#   preference: 口味标签,      # 最爱
#   dislikes: [口味标签],      # 讨厌
#   regular: int|null,        # 常点普通菜 id
#   special_want: int|null,   # 想吃的特别菜 id
#   wish: int,                # 兼容现有：偏好的食材 id（供 UI/现有逻辑）
# }
```

约束：
- **移除** `ticket%4/%6` 对 `wish` 的直接决定；用模板 + 固定种子 RNG（保证测试可复现）。
- `special`（第三个到来的勇者，`ticket==2`）语义保留，但口味同样来自模板。

## 存档迁移（version 4 → 5）
- `snapshot()`：`version` 改 5；新增 `dishes_unlocked`（Array[int]）、`menu`（`{mains:[], sides:[], specials:[]}`）。
- `apply_save()`：旧档缺新字段时用默认值补齐；旧 `regular_menu[7]`、`offerings[3]`、`formulas[3]` 映射到新 `menu` + `dishes_unlocked`，映射规则写清（并写进 PR 摘要）。
- `save_store.validate()`：校验新字段类型/范围，同时放行旧结构（缺字段不报错）。

## 菜单容量（M1 验收）
- 普通主菜 6 选 4、自取 4 选 3、特别菜 6 选 3，超选拒绝。
- 容量上限做成 `dishes.gd` 常量，测试引用同一常量（避免魔数）。

## 新增测试
- `hotpot/tests/dishes.gd`：6 主菜 / 4 自取 / 6 特别可查；容量超选被拒；v4 旧档迁移正确；`menu`+`dishes_unlocked` 存档往返一致。
- `hotpot/tests/patrons.gd`：偏好辣味点辣味；讨厌辣味不主动点辣味（除非只剩辣味）；`special_want` 有库存优先点特别菜；满足偏好→`liked`、未满足→`missed_taste`。

## 硬约束（违反即打回）
1. 不破坏现有 13 个 suite；`tests/` 只增不删（除非规则替换，需 PR 写明）。
2. 数字守恒：每个改动对应「输入==输出」断言。
3. CI 全绿（`.github/workflows/godot-tests.yml` 已 fail-fast，红就是红）。

## 提交要求
- PR 标题：`feat(dishes-patrons): M1 菜谱表驱动 + M2 顾客口味`
- 摘要三行：**规则变化** / **存档字段** / **测试**。
