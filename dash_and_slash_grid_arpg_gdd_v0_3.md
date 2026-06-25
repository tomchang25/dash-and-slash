# Dash and Slash：6x6 Grid Telegraph ARPG 企劃書 v0.3

版本定位：第三版獨立統合版
文件目的：本文件為完整可獨立閱讀版本，不需要參照 v0.1 或 v0.2。
目前設計重點：6x6 小型 Arena、玩家即時 ARPG 操作、敵人 grid-based tactical logic、兩輪小怪加 Boss 的 micro run、pre-run card loadout、敵人無 movement collision。

---

## 1. 企劃定位

本作是一款以 **6x6 Grid Arena** 為核心的俯視角小型高密度動作遊戲。

玩家操作是正常即時 ARPG：自由移動、自由攻擊、Dash、hitbox / hurtbox 判定。
敵人與 Boss 則使用類戰棋邏輯：grid 佔位、grid pathfinding、面向、格子預警、格子發招範圍、行動節奏。

核心不是大地圖探索，也不是純格子戰棋，而是：

```txt
玩家自由 ARPG 操作
+
敵人用 grid-based tactical logic 出招
+
玩家讀格子預警、抓側背、Dash 破盾、爆發輸出
```

### 1.1 核心戰鬥循環

```txt
觀察敵人面向
→ 讀 grid-based attack telegraph
→ 用自由移動 / Dash 避開危險格
→ 抓側面或背後攻擊 Guard
→ 用 Dash Attack 製造高收益破盾
→ Guard Break 造成 Stagger
→ Stagger 期間爆發 HP 傷害
→ 進入下一輪敵人行動節奏
```

### 1.2 遊戲型態

目前版本先不做完整 roguelite 路線，不做 run 中升級選項，不做大地圖探索。

本作目前設計為：

```txt
Pre-run Build
→ Micro Arena Run
→ Performance Result
→ Build Adjustment
```

一個 run 是一個短時間 combat trial，而不是長線探索關卡。

---

## 2. 核心設計支柱

## 2.1 玩家必須感覺自己在玩 ARPG

玩家不鎖格、不回合制、不被棋盤移動限制。

玩家應該可以：

```txt
自由移動
自由攻擊
用 Dash 切位
用 Dash Attack 進攻
用 hitbox 打中敵人 hurtbox
用自身位置抓正面 / 側面 / 背後
```

## 2.2 敵人意圖必須清楚

敵人攻擊不是突發 hitbox，而是先以格子預警表現。

玩家必須可以快速讀懂：

```txt
哪些格子即將危險
Boss 面向哪裡
Boss 下一招從哪裡打出來
哪裡是側面或背後
破盾還差多少 Guard damage
```

## 2.3 判定必須可信

本作混用 grid telegraph 與 free movement，因此判定不能讓玩家覺得詐欺。

基本原則：

```txt
敵人意圖 = grid
玩家操作 = free movement
實際命中 = hitbox / hurtbox
正側背 = direction resolver
```

## 2.4 Meta 只改變打法，不喧賓奪主

Meta 不以基地經營、材料農場、永久數值堆疊為核心。

目前 meta 只做卡片配件：

```txt
1 張 Major Card
+
3 張 Minor Card
```

Major Card 改整輪打法。
Minor Card 只做素質與手感調整。

---

## 3. 戰鬥場地

## 3.1 Arena 規格

| 項目                    | 規格                                   |
| ----------------------- | -------------------------------------- |
| Arena Size              | 6x6 grid                               |
| Tile Count              | 36                                     |
| 玩家移動                | 即時自由移動                           |
| 敵人移動                | Grid-based                             |
| 小怪尺寸                | 1x1 grid actor                         |
| Boss 尺寸               | 2x2 grid actor                         |
| 攻擊預警                | Grid / tile telegraph                  |
| 實際命中                | Hitbox / Hurtbox                       |
| 敵人 movement collision | 無                                     |
| 玩家 movement collision | 只對場地邊界、地形障礙、特殊招式障礙物 |

## 3.2 Grid 的用途

Grid 用於：

```txt
敵人 AI
敵人巡路
敵人佔位
敵人面向
Boss 2x2 body logic
小怪 1x1 body logic
攻擊預警
攻擊範圍定義
發招時生成 hit volume
敵人之間 pathfinding 避讓
```

Grid 不用於：

```txt
限制玩家移動
鎖定玩家站格
判定玩家普攻是否命中
判定玩家是否能攻擊
把玩家操作變成回合制
```

## 3.3 World Coordinate 與 Grid Coordinate

玩家存在於 world coordinate。
敵人存在於 grid coordinate，但也有 world position 用於顯示、hurtbox 與 hitbox 判定。

建議規則：

```txt
玩家 world position 可換算成目前所在 tile，供敵人 AI 選目標。
敵人 grid position 決定戰棋邏輯。
敵人 world position 決定動畫、hurtbox、受擊與顯示。
```

---

## 4. Entity 規格

## 4.1 Player

玩家不是 grid actor，不佔 grid occupancy。

| 項目               | 規格                                              |
| ------------------ | ------------------------------------------------- |
| 移動方式           | Free movement                                     |
| Grid Occupancy     | 無                                                |
| Hurtbox            | Circle / capsule                                  |
| 攻擊               | Weapon hitbox                                     |
| Dash               | 短距離高速位移                                    |
| Dash Attack        | Dash path 或 Dash active window 造成 hitbox       |
| Movement Collision | Arena boundary、terrain obstacle、special blocker |

玩家可用目前 world position 換算所在 tile，供敵人選擇攻擊方向與 telegraph pattern。

## 4.2 Small Enemy

小怪是 1x1 grid actor。

| 項目               | 規格                                    |
| ------------------ | --------------------------------------- |
| Size               | 1x1                                     |
| Guard              | 1 Shield = 4 Guard Points               |
| Movement Collision | 無                                      |
| Hurtbox            | 有                                      |
| Grid Occupancy     | 有                                      |
| Facing             | 有                                      |
| Attack Telegraph   | 有                                      |
| 主要作用           | 逼位、干擾、封路、逼 Dash、製造側背難度 |

小怪不靠身體碰撞卡死玩家，而是靠 grid 行動與 attack telegraph 改變走位題目。

## 4.3 Boss

Boss 是 2x2 grid actor。

| 項目               | 規格                                 |
| ------------------ | ------------------------------------ |
| Size               | 2x2                                  |
| Guard              | 4 Shields = 16 Guard Points          |
| Movement Collision | 無硬碰撞                             |
| Hurtbox            | 大型 hurtbox，可覆蓋 2x2 body        |
| Grid Occupancy     | 2x2                                  |
| Facing             | 上 / 下 / 左 / 右，必要時可擴充 8 向 |
| Attack Telegraph   | 有                                   |
| Soft Body Rule     | 可選                                 |

2x2 Boss 的目的：

```txt
讓面向更清楚
讓側面 / 背後更有空間意義
讓 Dash route 有判斷
讓 grid attack pattern 更容易設計
讓 Boss 在 6x6 arena 內有足夠壓迫感
```

---

## 5. 碰撞策略

## 5.1 碰撞拆層

本作不把所有碰撞混成同一件事。

碰撞拆成三層：

```txt
Movement Collision
角色移動時會不會被擋住

Combat Hitbox / Hurtbox
攻擊有沒有打中

Grid Occupancy
敵人在戰棋邏輯上佔哪些格、能不能走、能不能發招
```

## 5.2 玩家 Movement Collision

玩家只對以下物件做 movement collision：

```txt
Arena 邊界
固定場地障礙物
特定敵方招式生成的障礙物
```

玩家不會被普通小怪與 Boss 身體硬擋。

## 5.3 敵人 Movement Collision

普通敵人與 Boss：

```txt
不擋玩家移動
不擋玩家 Dash
不與玩家發生物理推擠
只提供 hurtbox 與 grid occupancy
```

這可以避免：

```txt
小怪 collider 卡死玩家
Dash 卡在 Boss 邊角
2x2 Boss 把玩家擠飛
小怪互相推擠造成 pathfinding 混亂
```

## 5.4 敵人 Grid Occupancy

敵人雖然不擋玩家 movement，但在敵人 AI 與 pathfinding 中仍然佔格。

```txt
小怪佔 1 tile
Boss 佔 2x2 tiles
敵人彼此不能走進同一格
小怪 pathfinding 會避開 Boss occupied tiles
Boss 不會踩到小怪 occupied tile
```

也就是：

```txt
對玩家 movement：敵人不是牆
對敵人 AI：敵人是 occupied tiles
```

## 5.5 Boss Soft Body Rule

Boss 不做硬碰撞，但可加入 soft body rule 避免玩家長時間站在 Boss 身體中心。

Boss 可分成：

```txt
Outer Hurtbox
玩家攻擊可命中，用於受擊判定

Inner Body Zone
不作為硬碰撞，只用於避免玩家停在 Boss 視覺身體中心
```

Inner Body Zone 可選處理：

```txt
玩家在內圈移速降低
玩家被輕微推出
玩家不能在內圈開始普攻
Dash 不能停在 Boss 中心區
```

MVP 可先只做 soft push，或暫時完全不做，優先驗證核心戰鬥。

## 5.6 特殊招式障礙物

特定敵方招式可以生成真正的 movement blocker。

範例：

```txt
Stone Wall
Ice Pillar
Spike Barrier
Shield Line
Temporary Block Tile
```

用途：

```txt
限制 Dash 路線
切斷側背路徑
改變 arena 解題方式
逼玩家等待、繞路或先處理其他威脅
```

這些障礙物必須有明確視覺語言，不能與普通敵人身體混淆。

---

## 6. 命中、方向與傷害判定

## 6.1 三段式判定

玩家攻擊不直接用 hitbox 接觸點決定正側背。

判定拆成三段：

```txt
Hitbox / Hurtbox Resolver
判斷有沒有命中

Direction Resolver
判斷攻擊來源相對目標面向屬於 Front / Side / Back

Damage Resolver
根據攻擊類型、方向、Guard 狀態、Stagger 狀態計算傷害
```

## 6.2 基本命中流程

```txt
Player attack hitbox overlap Enemy hurtbox
→ 產生 HitEvent
→ Direction Resolver 判斷 Front / Side / Back
→ 查表取得 Guard Damage
→ 套用 HP Damage
→ 檢查 Guard Break
→ 檢查 Dash Attack bonus
```

## 6.3 正面、側面、背後判定

近戰攻擊與 Dash Attack 的方向判定依據：

```txt
攻擊者 body center / attack origin
相對於
目標 body center 與 facing vector
```

不使用 hitbox overlap point 判斷正側背。

原因：

```txt
玩家站 Boss 正面
橫掃 hitbox 掃到 Boss 側後角
如果用接觸點判定，可能被錯算成側面或背刺
```

本作要獎勵的是玩家身體站位，不是攻擊判定盒碰到哪個角落。

## 6.4 2x2 Boss 的方向判定

Boss 2x2 時，建議使用 local space 判定。

流程：

```txt
取得 attacker origin world position
轉換到 Boss local space
根據 Boss facing 決定 local forward
用 local position 分類 Front / Side / Back
```

簡化規則：

```txt
攻擊者位於 Boss 面向前方區域 = Front
攻擊者位於 Boss 左右區域 = Side
攻擊者位於 Boss 背後區域 = Back
```

可接受少量模糊區，但必須符合玩家直覺。

## 6.5 Dash Attack 方向判定

Dash Attack 命中時也使用玩家 body center 判定方向。

```txt
Dash hitbox overlap Enemy hurtbox
→ 用玩家當下 body center 相對 enemy facing 判斷 Front / Side / Back
→ 套用 Dash Guard Damage
```

Dash 不會被普通敵人身體停住。

```txt
Dash 路徑經過敵人 hurtbox
→ 觸發 Dash Attack hit
→ Dash 繼續完成位移
```

只有特殊障礙物可以阻擋 Dash。

---

## 7. 投射物與炸彈判定

投射物與炸彈不使用近戰正側背邏輯。

它們不需要整套系統分開，但需要獨立的 direction rule。

## 7.1 共用 DamageEvent

所有攻擊仍可共用 DamageEvent。

```ts
export type DirectionRule =
	| "attackerOriginVsTargetFacing"
	| "projectileVelocityVsTargetFacing"
	| "explosionCenterVsTargetFacing"
	| "fixedNoDirection";

export interface DamageEvent {
	targetId: string;
	sourceId: string;
	attackType: AttackType;
	hitPosition: Vector2;
	attackOrigin: Vector2;
	directionRule: DirectionRule;
	baseHpDamage: number;
	baseGuardDamage: number;
	staggerBonus: number;
}
```

## 7.2 Projectile

MVP 建議：

```txt
Projectile 命中使用 hitbox / hurtbox
Guard Damage 固定
不吃 Front / Side / Back 倍率
DirectionRule = fixedNoDirection
```

未來可由特定 Major Card 改寫：

```txt
Projectile 可用 projectile velocity 判斷正側背
Projectile 從背後命中可造成額外 Guard Damage
```

但第一版不建議開放，避免遠程壓過近戰繞背核心。

## 7.3 Bomb / Explosion

MVP 建議：

```txt
Explosion 使用 radial hitbox
Guard Damage 固定或距離衰減
不吃 Front / Side / Back 倍率
DirectionRule = fixedNoDirection
```

未來可由特殊 Major Card 改寫：

```txt
Explosion center 相對敵人面向判斷方向
把炸彈丟到 Boss 背後可造成額外 Guard Damage
```

這會形成投放解題玩法，不列入第一版核心。

---

## 8. Guard / Shield / Stagger 系統

## 8.1 術語

| 中文   | 英文         | 說明                 |
| ------ | ------------ | -------------------- |
| 盾牌   | Shield       | UI 上顯示的盾牌 icon |
| 軀幹值 | Guard Points | 實際被削減的數值     |
| 破盾   | Guard Break  | Guard 歸零時觸發     |
| 暈眩   | Stagger      | 破盾後的可輸出狀態   |

## 8.2 Guard 數值

每個 Shield icon 代表 4 Guard Points。

| 單位 | Shield | Guard Points |
| ---- | -----: | -----------: |
| 小怪 |      1 |            4 |
| Boss |      4 |           16 |

## 8.3 Normal Attack Guard Damage

| 命中角度 | Guard Damage |
| -------- | -----------: |
| Front    |            1 |
| Side     |            2 |
| Back     |            4 |

設計效果：

```txt
正面普攻可以推進破盾，但效率最低
側面普攻是穩定打法
背後普攻可以直接破小怪 1 Shield
玩家會自然追求側背位
```

## 8.4 Dash Attack Guard Damage

| 命中角度 | Guard Damage |
| -------- | -----------: |
| Front    |            1 |
| Side     |            4 |
| Back     |            8 |

設計效果：

```txt
Dash Attack 是主要高收益破盾工具
側面 Dash Attack 等於打掉 1 Shield
背後 Dash Attack 等於打掉 2 Shields
正面 Dash Attack 效率低，避免無腦撞臉
```

## 8.5 Guard Break

當 Guard 歸零：

```txt
目標進入 Stagger
取消當前發招
無法行動
承受額外 HP 傷害
顯示盾碎與暈眩 FX
```

建議初版：

| 項目                 |         值 |
| -------------------- | ---------: |
| Stagger Duration     |       3 秒 |
| Stagger Damage Taken |       x1.5 |
| Stagger 結束         | Guard 回滿 |

之後可調整為 Stagger 結束後 Guard 回復 50% 或依敵人類型設定。

## 8.6 Dash Attack Bonus

Dash Attack 在以下條件觸發額外 HP 傷害與 FX：

```txt
Dash Attack 造成 Guard Break
Dash Attack 命中已 Stagger 目標
```

建議初版：

| 條件                          | 效果                                            |
| ----------------------------- | ----------------------------------------------- |
| Dash Attack 造成 Guard Break  | Bonus HP Damage x2.0、強 hit stop、盾碎 FX      |
| Dash Attack 命中 Stagger 目標 | Bonus HP Damage x2.5、重擊 FX、短暫 slow motion |

---

## 9. Player Combat

## 9.1 基礎操作

| 操作          | 說明                                   |
| ------------- | -------------------------------------- |
| Move          | WASD / 左搖桿自由移動                  |
| Aim / Facing  | 滑鼠方向 / 右搖桿方向 / 自動朝最近敵人 |
| Normal Attack | 近戰 hitbox，可依 Major Card 改變形狀  |
| Dash          | 短距離高速位移，有 CD                  |
| Dash Attack   | Dash 過程或結束瞬間產生攻擊判定        |

## 9.2 Dash 設計

Dash 是本系統最重要的動作資源。

Dash 應同時具備：

```txt
避開 telegraph 的能力
快速切入側面或背後的能力
高收益破盾能力
失誤時吃招的風險
```

建議初版：

| 項目               |                    建議值 |
| ------------------ | ------------------------: |
| Dash Distance      |            1.2～1.5 tiles |
| Dash Duration      |             0.18～0.25 秒 |
| Dash Cooldown      |               1.8～2.5 秒 |
| I-frame            |                極短或沒有 |
| Dash Attack Window | Dash 前半段或結束撞擊瞬間 |

如果 Dash 有過長無敵，玩家會把它當萬能閃避，而不是高風險切位攻擊。初版應偏向進攻資源，而不是純防禦資源。

## 9.3 Dash 與特殊障礙物

普通敵人不擋 Dash。
特殊招式障礙物可以阻擋 Dash。

```txt
Dash 撞到特殊 barrier
→ 停止 / 取消 Dash Attack / 受傷 / 反彈
```

具體效果可依障礙物類型設定。

---

## 10. 敵人 AI 與行為節奏

## 10.1 Enemy Action Cycle

敵人使用類戰棋節奏，但不是回合制。

基礎流程：

```txt
Patrol / Reposition
→ Face Target
→ Select Attack Pattern
→ Telegraph
→ Commit Attack
→ Recovery
→ Vulnerable Window
```

## 10.2 狀態機

```txt
Idle
  -> Reposition
  -> FaceTarget
  -> Telegraph
  -> Attack
  -> Recovery
  -> Idle

Any State
  -> GuardBreak
  -> Stagger
  -> RecoverGuard
  -> Idle
```

## 10.3 行為節奏建議

| 階段          |      小怪 |      Boss |
| ------------- | --------: | --------: |
| Reposition    | 0.3～0.6s | 0.5～1.0s |
| Face Target   | 0.1～0.2s | 0.2～0.4s |
| Telegraph     | 0.5～0.8s | 0.8～1.5s |
| Attack Active | 0.1～0.4s | 0.2～0.8s |
| Recovery      | 0.3～0.6s | 0.5～1.2s |

Boss telegraph 可以較長，因為玩家需要同時判斷：

```txt
Boss 2x2 面向
危險格
Dash CD
側背位置
小怪干擾
特殊障礙物
```

---

## 11. Attack Telegraph

## 11.1 術語

建議使用術語：

```txt
Grid-based Attack Telegraph
```

其他可用詞：

```txt
attack telegraph
tile telegraph
AoE indicator
warning zone
danger zone
wind-up telegraph
```

## 11.2 Telegraph 表現

每個被選中的危險 tile 會顯示預警。

預警階段建議分三層：

| 階段    | 視覺                 | 說明                 |
| ------- | -------------------- | -------------------- |
| Warning | 淡色格子             | 告訴玩家範圍即將危險 |
| Charge  | 顏色加深 / 閃爍加快  | 攻擊即將發生         |
| Active  | 爆光 / 斬擊 / 衝擊波 | 實際生成 hitbox      |

## 11.3 Telegraph 與 Hit Volume 一致性

流程：

```txt
AI 選擇 attack pattern
→ 根據 facing 旋轉 tile offsets
→ 在 arena 上標記 telegraph tiles
→ Telegraph 結束後，每個危險 tile 生成 hit volume
→ Player hurtbox overlap hit volume
→ 玩家受傷
```

規則：

```txt
Telegraph 顯示哪些格子，Active 時就由那些格子生成對應 hit volume
紅格外不應常態被打到
紅格內不應常態沒事
Active hitbox 可略小於視覺格，但不應大於視覺格太多
```

---

## 12. Run Flow

## 12.1 目前版本 Run 結構

目前版本不做完整 roguelite 路線，不做中間短期升級。

一個 run 結構：

```txt
選擇 Major Card
→ 裝備 3 張 Minor Card
→ 開始 Run
→ Wave 1：3 隻 1x1 小怪
→ Wave 2：3 隻 1x1 小怪
→ Boss：1 隻 2x2 Boss
→ 結算
→ 回到 Meta 配置
```

## 12.2 Run 長度目標

| 段落     |       長度 |
| -------- | ---------: |
| Wave 1   |  30～60 秒 |
| Wave 2   |  45～90 秒 |
| Boss     | 90～180 秒 |
| 完整 Run |  3～6 分鐘 |

## 12.3 無縫連接原則

Wave 之間不進入升級選擇畫面。

保留短節奏縫：

```txt
Wave clear
→ 0.8～1.5 秒緩衝
→ 下一波敵人落位 / Boss 入場
→ 戰鬥繼續
```

目的：

```txt
不打斷戰鬥節奏
讓玩家辨識下一波站位
讓玩家重新讀取血量、Dash CD、當前位置
讓 run 保持 micro trial 的密度
```

## 12.4 Wave 1：熟悉本輪打法

```txt
敵人數量：3 隻 1x1 小怪
功能：讓玩家理解本輪 Major Card 的操作變化
壓力：低～中
時間：30～60 秒
```

Wave 1 不追求高難度，而是讓玩家快速感覺本輪 build。

範例：

```txt
本輪普攻只能直刺
→ Wave 1 讓玩家立刻感覺攻擊變窄、需要對準

本輪普攻是 180 度
→ Wave 1 讓玩家感覺清怪覆蓋更穩
```

## 12.5 Wave 2：壓迫本輪弱點

```txt
敵人數量：3 隻 1x1 小怪
功能：測試 Major Card 缺點
壓力：中
時間：45～90 秒
```

Wave 2 開始加入：

```txt
卡位
夾擊
封側邊
逼 Dash
分散站位
延遲危險格
```

Wave 2 的目的不是單純加血，而是讓玩家不能只用 Wave 1 的舒適解法。

## 12.6 Boss：本輪打法期末考

```txt
敵人數量：1 隻 2x2 Boss
功能：完整測試讀面向、抓側背、Dash 破盾、Stagger 爆發
壓力：中～高
時間：90～180 秒
```

MVP 階段 Boss 戰可先不加小怪。
後續可視情況讓 Boss 在特定招式召喚少量小怪或特殊障礙物。

Boss 應該同時讓本輪 Major 的優點能發揮，也讓本輪 Major 的缺點造成實際壓力。

---

## 13. Meta Flow

## 13.1 Meta 目標

Meta 目前只做卡片配件，不做基地建設、長線材料農場、run 中升級、複雜技能樹。

Meta 目的不是讓玩家永久堆數值，而是讓玩家改變下一輪打法。

## 13.2 Meta Flow

```txt
Run 結算
→ 回到配置畫面
→ 選擇 1 張 Major Card
→ 裝備 3 張 Minor Card
→ 開始下一個 Run
```

玩家在 meta 層的思考應該是：

```txt
這輪我要用哪種攻擊形狀？
這輪我要靠 Dash 破盾，還是靠普攻穩定處理？
這輪要補移速、Dash CD、HP，還是 Stagger 傷害？
```

而不是：

```txt
我要升十個建築
我要清每日任務
我要農材料
我要處理一堆紅點 UI
```

---

## 14. Card System

## 14.1 裝備限制

```txt
Major Card：1 張
Minor Card：3 張
```

## 14.2 Major Card 設計原則

Major Card 負責改變整輪策略。

```txt
Major = 改核心動詞 / 改操作規則 / 改戰鬥策略
```

設計原則：

```txt
每張 Major 最好只有一個主要交易邏輯
Major 不只是加數值
Major 必須讓玩家換一種打法
Major 的優點與缺點都要在 Wave 2 與 Boss 中被驗證
```

## 14.3 Major Card 範例 1：直刺 Dash 流

效果：

```txt
普攻只能直刺
Dash Attack Guard Damage x2
```

玩法結果：

```txt
普攻覆蓋變窄
清小怪更吃站位與方向
正面亂砍變弱
Dash 成為主要破盾手段
Boss 戰重點變成抓側背 Dash
```

這張卡的本質交易：

```txt
犧牲普攻泛用性
換取 Dash 破盾爆發力
```

## 14.4 Major Card 範例 2：180 度攻擊落地 Dash 流

效果：

```txt
普攻變成前方 180 度攻擊
Dash Attack 不再看衝刺路徑命中
改為看落地位置的 circle hitbox
```

玩法結果：

```txt
普攻清怪更穩
小怪處理能力提高
Boss 側面輸出更容易
Dash 從衝撞穿位變成落點規劃
落地 circle 是 hitbox，不是 grid 判定
```

視覺要求：

```txt
Dash 落地 circle 必須明確表現成 hitbox / impact zone
不能看起來像 grid telegraph
避免與敵人 danger tile 混淆
```

## 14.5 Minor Card 設計原則

Minor Card 先全部做素質加成。

```txt
Minor = 補數值 / 修手感 / 微調風險
```

Minor 不改核心規則，不搶 Major 的玩法辨識度。

可能屬性：

```txt
HP
Move Speed
Base Damage
Guard Damage
Dash Cooldown
Dash Distance
Recovery Speed
Stagger Damage Bonus
Stagger Duration
Hitbox Size 微幅加成
```

需要注意的高風險必選屬性：

```txt
Dash Cooldown
Move Speed
Guard Damage
Stagger Damage Bonus
```

這些屬性會直接支配核心玩法，數值要保守。

---

## 15. Boss Attack Pattern 初版

Boss pattern 以 grid offsets 資料化。

## 15.1 Forward Cleave

Boss 朝面向方向攻擊前方 2x3 區域。

| 項目        | 規格                  |
| ----------- | --------------------- |
| Telegraph   | 前方 2x3 tiles        |
| Active      | 短時間斬擊 hit volume |
| Recovery    | 中等                  |
| Counterplay | Dash 到側面或背後     |

用途：

```txt
懲罰玩家站正面
鼓勵切側面
讓 Boss facing 有直接威脅
```

## 15.2 Line Charge

Boss 沿面向方向直線衝刺 3～4 格。

| 項目        | 規格                        |
| ----------- | --------------------------- |
| Telegraph   | 直線 tiles                  |
| Active      | Boss 移動 + 攻擊 hit volume |
| Recovery    | 較長                        |
| Counterplay | 側移後追背 Dash Attack      |

用途：

```txt
壓縮場地
懲罰站在遠距正前方的玩家
讓 Dash 可能是反擊，也可能是自殺
```

## 15.3 Cross Stomp

Boss 原地震地，攻擊自身周圍十字形範圍。

| 項目        | 規格                           |
| ----------- | ------------------------------ |
| Telegraph   | Boss 周圍十字 tiles            |
| Active      | 地面衝擊 hit volume            |
| Recovery    | 短～中                         |
| Counterplay | 退到斜角空位，等 recovery 反擊 |

用途：

```txt
防止玩家永遠貼背
逼玩家短暫離開
製造退開後再切入的節奏
```

## 15.4 Rotating Slash

Boss 先顯示單側危險格，短延遲後旋轉攻擊。

| 項目        | 規格                           |
| ----------- | ------------------------------ |
| Telegraph   | 左側或右側扇形 / tile line     |
| Active      | 旋轉 hit volume                |
| Recovery    | 中等                           |
| Counterplay | 觀察起手方向，切到另一側或拉開 |

用途：

```txt
測試玩家是否真的讀方向
創造側面不一定安全的情況
避免單一繞背策略過強
```

## 15.5 Summon / Spawn

Boss 在指定 tile 召喚 1x1 小怪或特殊障礙物。

| 項目        | 規格                                      |
| ----------- | ----------------------------------------- |
| Telegraph   | 指定 spawn tile                           |
| Active      | 產生小怪 / hazard / blocker               |
| Recovery    | 較短                                      |
| Counterplay | 提前清理、繞路、利用 Dash Attack 破小怪盾 |

用途：

```txt
增加場地壓力
讓玩家不能只盯 Boss
製造 Dash route 風險
導入特殊障礙物規則
```

---

## 16. 小怪設計

小怪是 1x1，不應搶走 Boss 主體地位。

## 16.1 小怪在 Run 中的功能

小怪不是血厚雜魚，而是走位題目。

用途：

```txt
改變玩家路線
逼玩家使用 Dash
干擾側背切入
封鎖安全格
與 telegraph 疊加造成壓力
讓玩家練習側背與 Dash 破盾
```

## 16.2 小怪類型範例

### Grunt

| 項目  | 規格            |
| ----- | --------------- |
| Size  | 1x1             |
| Guard | 4               |
| 攻擊  | 前方 1x1 或 1x2 |
| 作用  | 基礎干擾        |

### Marker

| 項目  | 規格                |
| ----- | ------------------- |
| Size  | 1x1                 |
| Guard | 4                   |
| 攻擊  | 標記 tile，延遲爆炸 |
| 作用  | 疊加 telegraph 壓力 |

### Blocker-type Enemy

注意：Blocker-type enemy 不代表它有 movement collision。
它的「擋路」應透過攻擊預警、站位壓力、特殊招式或短暫 blocker tile 表現。

| 項目  | 規格                         |
| ----- | ---------------------------- |
| Size  | 1x1                          |
| Guard | 4                            |
| 攻擊  | 慢速壓迫、短距威脅、暫時封格 |
| 作用  | 限制 Dash route、逼玩家換位  |

## 16.3 小怪破盾節奏

小怪只有 1 Shield = 4 Guard Points。

因此：

```txt
背後普攻直接破盾
側面 Dash Attack 直接破盾
背後 Dash Attack 溢出破盾並觸發重擊感
```

小怪是玩家理解側背與 Dash Attack 的低壓訓練目標。

---

## 17. HP Damage 與 Guard Damage 分工

本系統區分兩種傷害：

| 傷害類型     | 作用                       |
| ------------ | -------------------------- |
| HP Damage    | 真正擊殺敵人               |
| Guard Damage | 推進 Guard Break / Stagger |

玩家正面輸出仍可造成 HP 傷害，但 Guard 效率差。

最佳策略應是：

```txt
用側背攻擊削 Guard
→ 用 Dash Attack 創造 Guard Break
→ 在 Stagger 期間打 HP 爆發
```

建議初版倍率：

| 狀態                     | HP Damage Multiplier |
| ------------------------ | -------------------: |
| Normal                   |                 x1.0 |
| Stagger                  |                 x1.5 |
| Dash Attack breaks Guard |                 x2.0 |
| Dash Attack hits Stagger |                 x2.5 |

倍率是初版參考值，重點是讓玩家明顯感受到破盾爆發收益。

---

## 18. UI / UX

## 18.1 Boss UI

Boss UI 應包含：

```txt
Boss HP Bar
Boss Guard Shields
Boss 狀態：Normal / Telegraph / Recovery / Stagger
Stagger 狀態視覺與倒數感
```

Shield 顯示：

```txt
[盾][盾][盾][盾]
```

每個盾代表 4 Guard Points，可用四段切割、填充或破裂表現。

## 18.2 小怪 UI

小怪不需要大型 UI。

建議只顯示：

```txt
小型 HP 狀態
1 個小盾牌 icon
Stagger / Guard Break FX
```

## 18.3 Telegraph UI

Telegraph 必須比場景裝飾更清楚。

建議：

```txt
Warning tile 使用半透明底色
Charge 階段加粗邊框或閃爍
Active 階段出現斬擊、爆炸、衝擊波等 FX
Boss 面向用箭頭、身體朝向、前方標記共同表現
```

## 18.4 打擊回饋

| 事件              | 回饋強度                      |
| ----------------- | ----------------------------- |
| 普通命中          | 小 hit flash、小音效          |
| 側面命中          | 中等 hit flash、Guard chip FX |
| 背後命中          | 強 hit flash、明顯音效        |
| 破盾              | 盾碎、hit stop、音效、震動    |
| Dash 破盾         | 大型 FX、慢動作、重擊音效     |
| Dash 命中 Stagger | 最大強度 FX                   |

## 18.5 視覺語言區分

必須區分三種視覺：

```txt
敵人 grid telegraph = 危險格 / tile warning
玩家 hitbox = 武器揮擊 / dash impact / circle hotbox
特殊障礙物 = 明確實體 blocker
```

尤其是 180 度攻擊落地 Dash 流的 circle hotbox，不能看起來像敵人的 grid warning。

---

## 19. 數值初版

## 19.1 Player

| 項目                   |             建議值 |
| ---------------------- | -----------------: |
| Move Speed             | 1 tile / 0.8～1.0s |
| Normal Attack Duration |         0.25～0.4s |
| Normal Attack Cooldown |          0.1～0.2s |
| Dash Distance          |     1.2～1.5 tiles |
| Dash Duration          |        0.18～0.25s |
| Dash Cooldown          |          1.8～2.5s |
| Dash Attack Active     |          0.1～0.2s |

## 19.2 Boss

| 項目               |    建議值 |
| ------------------ | --------: |
| Size               |       2x2 |
| Shield             |         4 |
| Guard Points       |        16 |
| Stagger Duration   |        3s |
| Telegraph Duration | 0.8～1.5s |
| Recovery Duration  | 0.5～1.2s |

## 19.3 Small Enemy

| 項目               |    建議值 |
| ------------------ | --------: |
| Size               |       1x1 |
| Shield             |         1 |
| Guard Points       |         4 |
| Telegraph Duration | 0.5～0.8s |
| Stagger Duration   |        2s |

## 19.4 Run Timing

| 段落     |    建議值 |
| -------- | --------: |
| Wave 1   |   30～60s |
| Wave 2   |   45～90s |
| Boss     |  90～180s |
| Full Run |  3～6 min |
| Wave Gap | 0.8～1.5s |

---

## 20. Data-driven 結構建議

## 20.1 Attack Pattern Data

攻擊 pattern 應資料化。

```ts
export type Facing = "up" | "down" | "left" | "right";

export interface GridOffset {
	x: number;
	y: number;
}

export interface AttackPattern {
	id: string;
	name: string;
	telegraphDuration: number;
	chargeDuration: number;
	activeDuration: number;
	recoveryDuration: number;
	offsets: GridOffset[];
	damage: number;
	guardDamage?: number;
	rotateByFacing: boolean;
	createsMovementBlocker?: boolean;
	blockerDuration?: number;
}
```

## 20.2 Guard Component

```ts
export interface GuardComponent {
	maxGuard: number;
	currentGuard: number;
	shieldSize: number; // default: 4
	staggerDuration: number;
	staggerDamageMultiplier: number;
	recoverMode: "full" | "half" | "custom";
}
```

## 20.3 Hit Result

```ts
export type HitAngle = "front" | "side" | "back" | "none";

export type HitSource =
	| "normalAttack"
	| "dashAttack"
	| "projectile"
	| "explosion"
	| "hazard";

export interface HitResult {
	targetId: string;
	source: HitSource;
	angle: HitAngle;
	hpDamage: number;
	guardDamage: number;
	causedGuardBreak: boolean;
	targetWasStaggered: boolean;
	usedDirectionRule: DirectionRule;
}
```

## 20.4 Card Data

```ts
export type CardType = "major" | "minor";

export interface CardDefinition {
	id: string;
	type: CardType;
	name: string;
	description: string;
	modifiers: CardModifier[];
}

export interface CardModifier {
	stat?: string;
	operation?: "add" | "multiply" | "override";
	value?: number | string | boolean;
	ruleOverride?: string;
}
```

## 20.5 Collision Layer 建議

```txt
PlayerHurtbox
PlayerAttackHitbox
EnemyHurtbox
EnemyAttackHitVolume
WorldBoundary
TerrainObstacle
SkillBlocker
Pickup / Trigger
```

普通敵人 body 不進入 player movement collision layer。

---

## 21. MVP 範圍

## 21.1 MVP 目標

MVP 不做完整遊戲，只驗證核心戰鬥是否成立。

MVP 必須回答：

```txt
6x6 arena 是否足夠有走位決策
2x2 Boss 是否讓面向與繞背清楚
Grid telegraph + free movement 是否不會判定詐欺
敵人無 movement collision 是否改善手感
Guard / Dash Attack 是否形成風險報酬
玩家是否會主動追求側面與背後
1 Major + 3 Minor 是否能明顯改變 run 手感
兩輪小怪 + Boss 是否足以形成完整 micro run
```

## 21.2 MVP 內容

| 模組          | 內容                                              |
| ------------- | ------------------------------------------------- |
| Arena         | 6x6 grid，一張測試場地                            |
| Player        | 移動、普攻、Dash、Dash Attack                     |
| Collision     | 玩家只碰邊界與特殊障礙，敵人無 movement collision |
| Boss          | 2x2 Boss，一隻                                    |
| Small Enemy   | 1x1 小怪，一種或兩種                              |
| Boss Patterns | Forward Cleave、Line Charge、Cross Stomp          |
| Guard System  | Shield UI、Guard damage、Guard Break、Stagger     |
| Telegraph     | tile warning、charge、active                      |
| Card System   | 1～2 張 Major、數張 Minor                         |
| Run Flow      | Wave 1、Wave 2、Boss、結算                        |
| FX            | 命中、破盾、Dash 破盾、Stagger                    |

## 21.3 不納入 MVP

暫時不要做：

```txt
大地圖探索
run 中短期升級
完整 roguelite 路線
基地建設
長線材料農場
大量 Boss
大量小怪
完整裝備掉落
複雜技能樹
投射物背刺倍率
炸彈背刺倍率
敵人硬碰撞
完整物理推擠
```

---

## 22. 風險與對策

## 22.1 判定詐欺

風險：

```txt
玩家站在紅格外卻被打到
玩家站在紅格內卻常態沒事
hitbox 與 telegraph 視覺不一致
```

對策：

```txt
Telegraph tile 與 active hit volume 尺寸一致
Player hurtbox 不要太大
Active hitbox 可略小於 tile 視覺，但不能大於視覺太多
所有特殊判定要有明確 FX
```

## 22.2 Dash 過強

風險：

```txt
Dash 變成萬能閃避
玩家不讀招，只等 CD
Dash Attack 無腦正面撞也很強
```

對策：

```txt
Dash CD 不可太短
I-frame 極短或取消
正面 Dash Guard Damage 低
高收益只在側背、破盾、Stagger 成立
Boss 部分招式懲罰直線亂 Dash
```

## 22.3 繞背過強

風險：

```txt
玩家永遠貼背
Boss 沒有反制
戰鬥變成固定套路
```

對策：

```txt
Boss 加入 Cross Stomp
Boss 加入 Rotating Slash
小怪干擾 Dash route
Boss 轉向節奏不可太慢
特殊障礙物切斷側背路線
```

## 22.4 小怪太多造成混亂

風險：

```txt
畫面充滿 telegraph
玩家看不清 Boss 意圖
玩法變成清雜魚
```

對策：

```txt
每波先固定 3 隻小怪
小怪血量與 Guard 不要太高
小怪作用是改變走位，不是成為主要 DPS 壓力
```

## 22.5 Minor 變成固定答案

風險：

```txt
Dash CD、Move Speed、Guard Damage 永遠最佳
玩家不需要思考，只堆固定數值
```

對策：

```txt
Minor 數值保守
不同 Major 對不同 Minor 有不同需求
避免單一數值全面支配所有 build
```

## 22.6 敵人無碰撞造成穿模感

風險：

```txt
玩家站進 Boss 身體中心
視覺上像穿模
打擊距離感不清楚
```

對策：

```txt
Boss 使用 Outer Hurtbox + Inner Body Zone
Inner Body Zone 可 soft push
Boss 視覺中心區避免玩家長時間停留
攻擊命中距離與 FX 要清楚
```

---

## 23. 原型驗收標準

MVP 可被視為成功，若玩家在短時間測試內自然理解以下事項：

```txt
紅格是敵人即將攻擊的位置
Boss 面向會影響危險方向
打正面效率低
打側面與背後能更快破盾
Dash Attack 是高風險高收益攻擊
破盾後應該立刻輸出
Boss 發招後有可懲罰窗口
敵人身體不是牆
特殊障礙物才會擋玩家
Major Card 會改變整輪打法
```

如果玩家必須依靠大量文字教學才理解，代表 UI、FX、節奏或判定設計不夠清楚。

---

## 24. 開發優先順序

## 24.1 第一優先：核心戰鬥

```txt
6x6 arena grid
Player free movement
Player normal attack hitbox
Player dash / dash attack
Enemy hurtbox
Enemy grid occupancy
Boss 2x2 body 與 facing
Tile telegraph
Telegraph tile 轉 active hit volume
Guard / Shield / Stagger
Direction Resolver
```

## 24.2 第二優先：Run 與敵人內容

```txt
Wave 1 / Wave 2 / Boss run flow
1x1 小怪
Boss 三種 pattern
Shield UI
Dash Attack bonus FX
Wave gap 與 Boss 入場節奏
```

## 24.3 第三優先：Meta 與卡片

```txt
Major / Minor 裝備畫面
1～2 張 Major Card
基礎 Minor Card
Run 結算
重新配置流程
```

## 24.4 第四優先：擴充驗證

```txt
更多 Boss pattern
更多小怪類型
特殊障礙物招式
更多 Major Card
更多 Minor Card
更多 FX 與音效層級
```

---

## 25. 目前版本設計鎖定項目

以下為 v0.3 目前鎖定方向：

```txt
Arena 使用 6x6 grid
玩家是 free movement ARPG 操作
敵人與 Boss 使用 grid-based tactical logic
小怪是 1x1
Boss 是 2x2
Run = 兩輪 3 隻小怪 + 1 隻 Boss
Run 中不做短期升級
Meta = 1 Major + 3 Minor
Major 改整輪策略
Minor 只做素質加成
敵人不做玩家 movement collision
玩家只碰場地邊界、固定障礙、特殊招式障礙物
命中用 hitbox / hurtbox
正側背用 attacker origin 相對 target facing 判定
投射物與炸彈不吃正側背，除非 Major 改寫
Dash Attack 是主要高風險破盾工具
Guard Break 造成 3 秒 Stagger
```

---

## 26. 術語表

| 術語                        | 說明                                      |
| --------------------------- | ----------------------------------------- |
| Grid-based Attack Telegraph | 以格子顯示敵人即將攻擊的範圍              |
| Tile Telegraph              | 格子預警，同上                            |
| Danger Zone                 | 危險格                                    |
| Hitbox                      | 攻擊判定區                                |
| Hurtbox                     | 受擊判定區                                |
| Guard                       | 軀幹值 / 盾值                             |
| Shield                      | UI 上的盾牌 icon，每個代表 4 Guard Points |
| Guard Break                 | Guard 歸零觸發破盾                        |
| Stagger                     | 破盾後的暈眩與爆發窗口                    |
| Movement Collision          | 移動時會不會被擋住                        |
| Grid Occupancy              | 敵人在 grid logic 中佔哪些格              |
| Direction Resolver          | 判斷 Front / Side / Back 的邏輯           |
| Damage Resolver             | 計算 HP 與 Guard 傷害的邏輯               |
| Major Card                  | 改變整輪策略的卡片配件                    |
| Minor Card                  | 素質加成或手感修正的卡片配件              |
