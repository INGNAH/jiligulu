# Sprint 2 分派单（给 Codex）— M3 烹饪 / 备菜玩法

> 依据：`docs/营业基础玩法设计规格.md` §5。
> 前置：**M1（菜谱表）+ M2（顾客口味）已合入 main 且 CI 绿**。未满足前置不要开工。
> 分支：从 `main` 新建 `feat/cooking`。

## 目标一句话
把「一键装盘」升级为通用的、有火候判定的烹饪；把单一 `mastery` 拆成按菜谱分别累计的熟练度。

## 现状硬编码（hotpot/main.gd）
- `var mastery = 0`：单一熟练度，需改为 `mastery_by_dish`。
- `func finish_cook(success: bool)`：只服务「清炖霜牛」一道菜，需泛化。
- `var cooking / cook_time / cook_cursor`：火候条状态，需支持任意菜谱。
- `show_kitchen()` / `show_preparation()`：入口只做炖菜，需列出全部可做菜谱。

## 玩法规则（沿路线图「熟菜快做，研发和人物菜细做」）

### 通用火候条
- 统一 `cook_dish(dish_id)` 状态机，复用现有 `cooking/cook_time/cook_cursor`。
- 火候窗口 `[40, 70]`，不同菜可调窗口宽窄：
  - 普通菜（`tier=="normal"`）：窗口宽（如 `[30, 80]`），失误成本低。
  - 招牌/特别菜（`tier=="signature"` 或 `kind=="special"`）：窗口窄（如 `[40, 70]`），更考验操作。
- 判定三档：窗口内 = 成功；过火 / 夹生 = 失误。

### 快做（普通主菜）
- 营业期在后厨，选普通主菜 → 1.5–2 秒火候条。
- 成功出 2 盘；失误出 1 盘（或废料，二选一并写死，见「守恒」）。

### 细做（特别菜 / 定制单）
- 保留现有「原方 + 加料」多步骤 + 火候条，加料影响 `tags`（沿用 `recipes.gd`，不得重写）。

### 快捷制作
- 某菜熟练 ≥3 解锁该菜「快速装盘」：跳过火候条，直接按成功结算，但不额外消耗原料。

## 数据接入

### `mastery_by_dish`
- `var mastery_by_dish: Dictionary = {}`（`dish_id -> int`）。
- 迁移：旧单一 `mastery` 映射为「清炖霜牛」这道菜的熟练度（清炖霜牛在 M1 表里的 id）。
- 快装解锁判断 `mastery_by_dish.get(dish_id, 0) >= 3`。

### `finish_cook` 泛化
```gdscript
func finish_cook(dish_id: int, quality: int) -> bool
# quality: 0=失误, 1=成功   （与现有 finish_cook(true/false) 兼容，内部映射）
```

## 守恒约束
- `cook` 前后 `raw` 与 `ready_food` 总量守恒：写一条「原料减少 == 成品增加」的断言。
- 失误出 1 盘 vs 废料的规则，写进 PR 摘要并配对应测试，避免「凭空产生/消失」。

## 新增测试（hotpot/tests/cooking.gd）
- [ ] 普通菜快做：窗口内成功 → 出 2 盘；过火/夹生 → 出 1 盘或废料（按上面写死规则）。
- [ ] 特别菜加料后 `tags` 正确包含所加口味。
- [ ] 某菜熟练 ≥3 解锁快速装盘，且不额外消耗原料。
- [ ] `cook` 前后 `raw`/`ready_food` 总量守恒。
- [ ] 旧档 `mastery` 迁移为对应菜谱的 `mastery_by_dish` 条目。

## 硬约束
1. 不破坏现有 suite；`tests/` 只增不删。
2. 数字守恒，配断言。
3. CI 全绿。

## 提交要求
- PR 标题：`feat(cooking): M3 通用火候烹饪 + 按菜熟练度`
- 摘要三行：**规则变化 / 存档字段 / 测试**。
