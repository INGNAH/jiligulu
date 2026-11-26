# Sprint 3 分派单（给 Codex）— M4 员工岗位与雇佣

> 依据：`docs/营业基础玩法设计规格.md` §6。
> 前置：**M1 + M2 + M3 已合入 main 且 CI 绿**。未满足前置不要开工。
> 分支：从 `main` 新建 `feat/staff-roles`。

## 目标一句话
把「点单/送餐/补餐」从固定自动 worker，变成可雇佣、可排班、可成长的三岗位决策。

## 现状硬编码（hotpot/main.gd）
- `var employee = false`：单个布尔，只代表「是否雇了补餐露米」。
- `var staff_exp / staff_trips`：补餐员单一成长。
- `var staff_zone`：单一员工的分区指派。
- `func hire()`：单次招聘。
- `service_team`：点单/送餐是固定 2 个自动 worker，无条件参与。

## 玩法规则

### 三岗位
| 岗位 | 作用 | 未雇佣的代价 |
|---|---|---|
| 点单员 `order` | 到桌边记录主菜 | 主菜等待显著变长（玩家可亲自点单） |
| 送餐员 `deliver` | 从后厨送菜到桌 | 玩家亲自送 |
| 补餐员 `refill` | 从厨房补自取台 | 食材台缺货更快（玩家亲自补） |

### 雇佣
- `employee: bool` → `staff: {order: {hired, exp, zone}, deliver: {...}, refill: {...}}`。
- 每个岗位独立雇佣（一次性费用）+ 独立日工资。
- 迁移：旧 `employee==true` → `staff.refill.hired=true`；旧 `staff_exp` → `staff.refill.exp`；旧 `staff_zone` → `staff.refill.zone`。

### 成长
- 每个岗位独立经验/等级，影响速度或携带量（复用 `staff_speed/staff_level/staff_capacity` 的思路，按岗位分别计）。

### 排班
- 准备期可给每个岗位指派「优先照看某分区」（`zone`，沿用现有 `staff_zone` 逻辑）。

## 数据接入
- `service_team`：有 `order`/`deliver` 员工则用员工实体，无则「玩家承担或降速」（降速幅度做成可测阈值常量，测试引用同一常量）。
- `hire()` → `hire(role)`。
- 日终工资按「已雇佣岗位数」结算，守恒。

## 存档字段
- `staff: {order:{hired,exp,zone}, deliver:{...}, refill:{...}}`，迁移自旧 `employee/staff_exp/staff_zone`。
- `save_store.validate()` 校验新结构，放行旧结构。

## 新增测试（hotpot/tests/staff.gd）
- [ ] 无点单员时，主菜等待显著变长（有可测阈值）。
- [ ] 雇佣各岗位后，对应环节自动恢复。
- [ ] 各岗位经验/等级独立成长，携带量/速度按等级提升。
- [ ] 工资按「已雇佣岗位数」结算，守恒。
- [ ] 旧档 `employee/staff_exp/staff_zone` 正确迁移到 `staff.refill.*`。

## 硬约束
1. 不破坏现有 suite；`tests/` 只增不删。
2. 数字守恒（尤其工资、经验、携带量）。
3. CI 全绿。

## 提交要求
- PR 标题：`feat(staff-roles): M4 三岗位雇佣与成长`
- 摘要三行：**规则变化 / 存档字段 / 测试**。

---

## 附：M1–M4 完成后建议做一次统一收尾（不算本目标范围，仅提示）
- 拆分 `main.gd`（营业规则 / 顾客 / 员工 / UI / 绘制）。
- 跑一遍 Windows 实机验证。
- 更新 README 的版本记录（当前写的是 v0.3.2，落后于代码）。
