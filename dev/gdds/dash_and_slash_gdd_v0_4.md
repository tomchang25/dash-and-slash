# Dash and Slash：Infinite Chaos Grid Arena 企劃書 v0.4

版本定位：取代 v0.3，反映目前 codebase 實際走向。
文件目的：v0.3 已 outdated，本版承認並收斂 codebase 已成形的方向，不再假設回頭做 6x6 pre-run-only micro boss duel。

---

## 0. 與 v0.3 的差異（先講清楚，避免文件互打架）

| 項目     | v0.3                                     | v0.4                                                                                |
| -------- | ---------------------------------------- | ----------------------------------------------------------------------------------- |
| 定位     | 6x6 小型 boss duel prototype             | Infinite chaos wave survival roguelite                                              |
| Run 結構 | Pre-run build → 兩輪小怪 + 1 Boss → 結算 | Wave → Reward → Wave 無限循環，死亡才結束                                           |
| Arena    | 6x6 固定                                 | 中大型（現況 16x16, starting land 8x8），可被地形效果動態破壞                       |
| Meta     | 1 Major + 3 Minor，run 中不升級          | Major 上限 4 個（改技能規則），Minor 無限疊（改數值），run-time reward 就是內容主體 |
| Boss     | 2x2 tactical boss，三招式，讀招型設計    | 取消傳統 boss 定位；ModeEnemy 變成每 5 波出現的 elite，不結束 run                   |
| 基調     | ARPG / 讀招 / 精準側背                   | Brotato 式爽快混亂，方向攻擊與破盾仍是主軸，但目標是"疊到失控"                      |
| Dash     | 破盾工具之一                             | 核心清場動作，可被 Major effect 改成 Chain Dash / Smash 等行為                      |

如果之後 v0.3 和 v0.4 有衝突，一律以 v0.4 為準；v0.3 僅保留作歷史參考，不再是實作依據。

---

## 1. 企劃定位

一款以**中型動態網格競技場**為核心的俯視角高密度動作 roguelite。

玩家操作是自由 ARPG：自由移動、自由攻擊、Dash。
敵人使用 grid-based tactical telegraph，但**數量與花招服務於製造視覺混亂，而不是服務於逐招精算**。

核心不是「讀懂每一招」，而是：

```txt
玩家自由 ARPG 操作 + Dash 清場
+
敵人用 grid telegraph 製造看得懂的混亂
+
Reward 疊加讓 build 逐漸失控
+
地形隨每波固定 Tile Op 逐漸碎裂
=
一場從「小心翼翼」滑向「一個 Dash 清全場」的失控曲線
```

### 1.1 核心迴圈

```txt
Wave 清場
→ 短暫 wave gap
→ 三選一 reward（Major / Minor / 未來壓力）
→ 效果立即套用
→ 下一波敵人數量與強度提升
→ 重複，直到玩家死亡
```

沒有「結算後重新配置」這種 pre-run 概念——build 是在 run 內滾出來的，這就是內容本身，不是 run 前的準備動作。

### 1.2 遊戲型態

```txt
Infinite Wave Survival
每 wave：基礎敵人數量固定成長
每 5 wave：敵人屬性 milestone 提升（不含 Guard）+ 依排程丟 ModeEnemy elite + 補 10 塊 Expand Land
Run 結束條件：玩家死亡（不是破關）
```

---

## 2. 核心設計支柱

### 2.1 玩家永遠是自由移動

不鎖格、不回合制、不被棋盤移動限制。這條與 v0.3 相同，未變動：玩家 world position 每 physics frame 換算成 grid cell 供敵人 AI 使用，但玩家本身不佔 grid occupancy。

### 2.2 敵人意圖必須「看得懂」，即使畫面很亂

這是本版最容易被犧牲、但最不能被犧牲的支柱。混亂是設計目標，但**混亂必須建立在一致的視覺語言上**：

```txt
顏色 = attack pattern
Telegraph 顏色/相位 = 危險階段（WARNING / CHARGE / ACTIVE / SPAWNING）
Dash 命中回饋 = 成功一定要跟失敗長得不一樣
Guard Break = 一定要有大事件感（畫面震動、閃光、音效）
Corrupt Land = 視覺絕對不能跟敵人 hitbox 混淆
```

底線：**畫面可以很滿，但玩家永遠要能回答「我剛剛是怎麼死的」。** 如果做不到，代表視覺語言沒做夠，不是敵人數量的問題。

### 2.3 判定必須可信

沿用 v0.3 三段式判定，未變：

```txt
敵人意圖 = grid telegraph
玩家操作 = free movement
實際命中 = hitbox / hurtbox
正側背 = Direction Resolver（attacker body center 相對 target facing，不用 hitbox overlap point）
```

### 2.4 Dash 是清場核心，不是單純位移技

Dash 從「破盾工具之一」升級成「整個中後期爽感的載體」：

```txt
前期：Dash 命中即大量破盾（見 6.1）+ 側背穿透傷害（見 6.2）+ Stagger 期間 2x 爆發（見 6.3）
中期：Reward 疊起來，Dash 開始連鎖（Chain Dash）
後期：Dash 變形（Smash）；若疊到 Guard Shredder / Execution 兩個 Major，背刺與 Stagger 收尾可以直接瞬破瞬殺
```

方向性攻擊與破盾仍然「有收益」——但收益的終點不是精準決鬥的成就感，而是**授權玩家把整個系統玩到失控**。

### 2.5 Reward 是內容主體，不是額外系統

Major（最多 4 個，改規則）+ Minor（無限疊，改數值）不是「錦上添花」，是遊戲唯一的長線內容產出方式。取消 v0.3「Meta 只改變打法、不喧賓奪主」這條——這版就是要 Meta 喧賓奪主，因為喧賓奪主本身就是賣點（"一個 Dash 清場"）。

---

## 3. 戰鬥場地

### 3.1 Arena 規格（更新）

| 項目                    | 規格                                              |
| ----------------------- | ------------------------------------------------- |
| Arena Size              | 中型（現況 16x16，起始 land 8x8），非 v0.3 的 6x6 |
| 玩家移動                | 即時自由移動，不佔 grid occupancy                 |
| 敵人移動                | Grid-based                                        |
| SmallEnemy              | 1x1，主力敵人，佔 spawn ≥ 60%                     |
| ModeEnemy (Elite)       | 1x1，每 5 波額外生成，不再是 boss，死亡不清場     |
| 攻擊預警                | Grid / tile telegraph                             |
| 實際命中                | Hitbox / Hurtbox                                  |
| 敵人 movement collision | 無                                                |
| 玩家 movement collision | 只對場地邊界、地形障礙、特殊招式障礙物            |
| 地形連通性              | 唯一硬性規則：land 必須維持連通，其餘允許碎裂     |

### 3.2 地形是動態的，而且允許看起來「亂」

v0.3 認為地形變化需要玩家能精算風險（tile preview 之類）。v0.4 明確放棄這個要求：**只要 land 保持連通，地圖越碎越符合設計意圖**，玩家理解的顆粒度停在「我選了激進 reward，場地會變小/變形」就夠，不需要精準 tile-level 可預測性。

地形效果分類：

| 類型                 | 行為                                         | 定位                                            |
| -------------------- | -------------------------------------------- | ----------------------------------------------- |
| Expand Land          | 新增安全連通地，每 5 波清完固定給 10 塊      | 節奏重置閥，長線理論上緩慢淨增長                |
| Tile Op（原 Move Land / Break Land） | 不再是 reward 選項；非 milestone wave 清完自動觸發一次，50% 機率位移 2 塊地（形狀改變、land 總量不變）、50% 機率移除 1 塊安全連通地；milestone wave 由 Expand Land 取代 | 固定節奏地形壓力，取代原本可被 Aggressive reward 疊加、幅度不可預期的地形卡 |
| Corrupt Land         | 固定生成一個 hitbox + VFX，每 0.5 秒小額扣血 | 逼位背景壓力，不當主傷害來源                    |
| Fortify Land（延後） | 阻擋 tile attack 在該格生成                  | 排在核心迴圈穩定後才做                          |

---

## 4. Entity 規格

### 4.1 Player

沿用 v0.3 的自由移動 / 無 grid occupancy 規格，新增 Build 相關欄位：

| 項目               | 規格                                                              |
| ------------------ | ----------------------------------------------------------------- |
| 移動方式           | Free movement                                                     |
| Grid Occupancy     | 無                                                                |
| Hurtbox            | Circle / capsule                                                  |
| 攻擊               | Weapon hitbox（普攻）                                             |
| Dash               | 基礎位移 + hitbox，可被 Major effect 改變行為（見第 7 節）        |
| Movement Collision | Arena boundary、terrain obstacle、special blocker                 |
| Run Build          | 持有 Major effects（≤4）、Minor effects（無上限）、觸發式效果掛勾 |

### 4.2 SmallEnemy（主力敵人，重新定位）

不再是 v0.3 裡「1x1 干擾用小怪」，而是**內容量的主要來源**。

| 項目           | 規格                                                         |
| -------------- | ------------------------------------------------------------ |
| Size           | 1x1                                                          |
| Attack Pattern | 6-8 種，透過 `EnemyAttackData` 資料化，不寫成獨立敵人類別    |
| 顏色綁定       | 每種 pattern 綁固定顏色，顏色即讀法                          |
| Spawn 佔比     | Base wave pool ≥ 60%                                         |
| Guard          | 沿用小怪規格：1 Shield = 4 Guard Points（數值細節見第 6 節） |
| 主要作用       | 內容多樣性、逼走位、製造混亂密度                             |

PuffEnemy / ChargeEnemy 兩個現有類別保留，作為 base wave pool 的其餘 40%，不再擴充新的獨立敵人 scene——新內容優先透過 SmallEnemy pattern 資料擴充。

### 4.3 ModeEnemy（Elite，非 Boss）

從「唯一的 boss」重新定位為「週期性強敵」：

| 項目         | 規格                                                                                                                                |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| Size         | 1x1                                                                                                                                 |
| 出現時機     | 每 5 波（Wave 5 / 10 / 15 / 20…），首發 1 隻                                                                                        |
| 出現數量成長 | 不建議線性 +1；建議如 Wave 5：1 隻、Wave 10：1 隻但屬性提升、Wave 15：2 隻、Wave 20：2 隻 + 額外 pattern，避免場面過早被 elite 淹沒 |
| 死亡規則     | 死亡不清場、不結束 run（與 v0.3 的 boss-clear-ends-run 相反）                                                                       |
| 模式         | 保留 TILE / PUFF / CHARGE 三模式輪替                                                                                                |
| Run 結束條件 | 不再與 ModeEnemy 死亡綁定；run 由玩家死亡結束                                                                                       |

Elite 不設獨立存活上限；改用 9.4 節的全域敵人同時存活上限（`12 + floor(wave/5)*4`）統一控管，多餘的 elite spawn 排隊等場上有空位再生成，不需要對 elite 另外寫淘汰規則。

---

## 5. 碰撞策略

沿用 v0.3 第 5 節，未變動：

```txt
Movement Collision / Combat Hitbox-Hurtbox / Grid Occupancy 三層拆開
玩家只對邊界、固定障礙、特殊招式障礙物做 movement collision
敵人不擋玩家 movement，只提供 hurtbox 與 grid occupancy
Dash 不會被普通敵人身體停住，只有特殊障礙物能擋
```

---

## 6. 命中、方向與傷害判定（數值更新）

三段式判定架構（Hitbox/Hurtbox Resolver → Direction Resolver → Damage Resolver）沿用 v0.3。v0.4 的修正方向是：**baseline 規則本身給到「大量傷害與破盾」，但保留有限數字；瞬間破盾與瞬殺改為 Major effect 才能拿到**，避免 baseline 直接把方向攻擊的上限焊死。

### 6.1 Guard Damage（盾值傷害，普攻與 Dash 共用同一套表）

不再區分「普攻較弱、Dash 較強」兩套表，Normal Attack 與 Dash 命中時使用同一套 Guard Damage：

| 命中角度 | Guard Damage             |
| -------- | ------------------------ |
| Front    | 8                        |
| Side     | `max(quarter_guard, 16)` |
| Back     | `max(half_guard, 32)`    |

`quarter_guard` / `half_guard` 以目標敵人的 `max_guard` 為基準計算。因為 Guard 上限**不隨 milestone 成長**（見 6.4），這兩個下限在整場 run 裡都維持有意義，不會出現「後期 Guard 太厚、下限形同虛設」的問題。

### 6.2 HP Damage Bypass（隔著 Guard 仍能穿透的 HP 傷害比例，普攻與 Dash 共用）

敵人 Guard 還沒破的情況下，命中角度決定這次攻擊有多少比例的基礎傷害會直接穿透打到 HP：

| 命中角度 | HP 傷害穿透比例                |
| -------- | ------------------------------ |
| Front    | 0（完全被 Guard 吸收，不穿透） |
| Side     | 0.1                            |
| Back     | 0.25                           |

這讓側背攻擊在 Guard 破盾之前就已經有實質收益，不用等到破盾才拿到回饋。

### 6.3 Stagger Burst Multiplier（破盾後爆發輸出倍率）

Guard 破盾、敵人進入 Stagger 之後，命中直接吃 HP 傷害，倍率如下：

| 攻擊來源      | Stagger 期間傷害倍率 |
| ------------- | -------------------- |
| 普攻（Slash） | 1.0x                 |
| Dash          | 2.0x                 |

這是 v0.3 第 1.1 節「Stagger 期間爆發 HP 傷害」的量化版本：Dash 在 Stagger 窗口的收益是普攻的兩倍，但**不是秒殺**——秒殺留給 6.4 的 Major effect。

### 6.4 瞬間破盾與瞬殺改為 Major Effect（不再是 baseline 規則）

上一版把「Dash 背後必破盾」與「Dash 命中 Stagger 敵人必秒殺」寫成 baseline 規則，這版收回：baseline 只給 6.1～6.3 的大數字，**瞬間效果變成兩個獨立的 Major effect**，玩家要主動選才拿得到：

```txt
Guard Shredder（Major）
Dash 背後命中直接把目標 Guard 歸零並進入 Stagger，無視 6.1 的 max(half_guard, 32) 計算。

Execution（Major）
Dash 命中已 Stagger 的敵人時，不套用 6.3 的 2.0x 倍率，而是直接秒殺。
```

這樣兩件事都變得有意義：baseline 玩家仍然打得動、打得爽，但「一個 Dash 清場」的終極形態要靠 build 疊出來，而不是預設就有。

Guard Shredder / Execution 是否對 ModeEnemy elite 生效（是否要給 elite 一個「免疫瞬殺」標記）留給實測調整，不當作 baseline 需要現在解決的問題。

Milestone 成長只影響 Def / HP / Damage，不影響 Guard（見 9.4）——這代表 6.1 的 Guard Damage 數字不需要隨波數重新校準。

### 6.5 SFX / Feedback 對應（供第 10 節視覺語言引用）

```txt
Guard 破盾瞬間 → 專屬 broken SFX
普攻打中有 Guard 的敵人 → blocked SFX + 對應 guard damage（穿透部分另計 HP damage 音效層）
普攻打中已破盾/staggered 敵人 → damaged SFX（1.0x）
Dash 打中有 Guard 的敵人 → blocked SFX
Dash 打中已破盾/staggered 敵人 → damaged SFX（2.0x），若持有 Execution Major → 改播秒殺專屬 SFX
若持有 Guard Shredder Major，Dash 背後命中瞬間破盾要另有專屬 SFX，跟一般 guard broken 區分開
```

---

## 7. Dash 系統與 Major / Minor Build 架構

### 7.1 為什麼不能直接在屬性上疊加

目前 `WaveRewardApplier` 是直接呼叫 `player.add_normal_attack_damage()` 這類方法，對純數值 reward 沒問題。但 Major effect 要做的是**改變 Dash 的行為本身**（例如把 Dash 換成 Smash），如果效果只是「呼叫方法改屬性」，之後再選一個會改變同一個行為的 Major，前一個效果就會被覆蓋或遺失。

### 7.2 PlayerRunBuild（新增資料結構，概念層級）

```txt
PlayerRunBuild
├─ major_effects: Array[MajorEffect]      # 上限 4，改規則 / 改行為
├─ minor_effects: Array[MinorEffect]      # 無上限，改數值 / 小規則
├─ stat_modifiers                          # Minor 累加結果的最終快取
├─ ability_overrides                       # 例如 dash_type = NORMAL / CHAIN / SMASH
└─ triggered_effects                       # on_dash_hit / on_kill / on_stagger 等掛勾
```

Dash 的實際行為在每次觸發時去問 build，而不是把行為寫死在屬性欄位上：

```txt
這次 dash 的 ability_override 是什麼型態？（Normal / Chain / Smash）
dash hit 之後有哪些 triggered_effects 要跑？
dash 擊殺後有哪些 triggered_effects 要跑？
```

這樣後續新增/替換 Dash 型態的 Major，不會把之前疊的其他效果弄丟。

### 7.3 Major Effect 範例（規則層級）

```txt
Chain Dash — Dash 命中後自動朝射程內最近敵人再次 Dash
Smash — Dash 改為指定範圍圓形重擊，命中範圍內全體 Guard Break，冷卻拉長
Guard Shredder — Dash 背後命中直接 Guard Break（正式定義見 6.4）
Execution — Dash 命中已 Stagger 的敵人直接秒殺，取代 6.3 的 2.0x 倍率（正式定義見 6.4）
Shockwave Dash — Dash 結束時額外產生一個 AoE hitbox
```

### 7.4 Minor Effect 範例（數值層級，無限疊）

```txt
+dash damage / -dash cooldown / +dash range
+attack range（資料化，讓 normal / dash / smash / 未來武器都能共用同一套 hit geometry 縮放）
+smash radius / +chain count / +one-shot threshold
+corrupt tick damage
```

> 已拍板：Chain Dash 與 Smash 互斥，同一 build 不能同時持有兩者，透過 exclusivity group 機制強制執行——見 12.1。兩個技能本身尚未實作，這裡先鎖定的是規則，不是技能內容。

---

## 8. Wave / Reward 無限迴圈

### 8.1 結構變更

取消 v0.3 的「兩輪小怪 + 1 Boss」與現行 code 的「4 個 normal wave + 1 個 boss wave」固定結構，改為：

```txt
Wave N 開始 → spawn telegraph → 敵人生成 → 敵人清空 → wave gap（2s）
→ 三選一 reward → 立即套用 → Wave N+1
```

不再有「boss 死亡 = run 結束」，改為「玩家死亡 = run 結束」。

### 8.2 數值成長（先求簡單、可調，不做 director AI）

```txt
wave_enemy_count = base + wave_number * per_wave_growth   # 具體常數留待調參
每 5 波：enemy_hp_multiplier += Δ
每 5 波：enemy_damage_multiplier += Δ（連帶影響 Def）
每 5 波：enemy_move/attack_speed 調整
每 5 波：額外生成 1 隻（或依 4.3 節排程）ModeEnemy elite
每 5 波清完：固定給 Expand Land x10
Guard（含 max_guard）不受 milestone 影響，只有 Def / HP / Damage 隨波數成長（見 6.4、9.4）
```

目標曲線：**正常一輪抓「第 20 波陣亡」為基準難度，「第 30 波」視為封頂表現**。具體 Δ 與 per_wave_growth 常數不在本文件鎖定，留給調參階段，但都要往這個目標校準。

### 8.3 Reward 應該讀起來像「交易」，不是單純升級

現行 reward 已有 Conservative / Balanced / Aggressive 三種 profile，但呈現上偏向「風險程度」而非「明確的 A 換 B」。v0.4 方向：**reward 文案要讓玩家看得到代價**，例如：

```txt
+20% Dash 傷害，但下一波 +2 隻敵人
+Dash 距離，但下一波敵人生命值提高
+攻擊距離，但下一波敵人防禦提高
+普攻傷害，但下一波敵人生成點更靠近玩家
```

這不是新系統，是既有 profile/effect 架構上補「明確可讀的 downside 文案」。

---

## 9. Enemy Spawn 與 Pattern 系統

### 9.1 Base Wave Pool（固定比例，不再是純隨機挑 scene）

```txt
Base Wave Pool（示意）：
60%+ SmallEnemy（顏色/pattern 當場隨機）
20% PuffEnemy
20% ChargeEnemy
```

### 9.2 Reward Pressure 不改變比例，而是加固定敵種壓力

```txt
Effect 觸發的是「固定敵種數量增量」，例如：
+3 SmallEnemy（下一波）
+1 ModeEnemy（milestone 提前觸發，若採用此設計）
+2 Corrupt SmallEnemy 變種（若做進階變種）
```

這樣 reward 的 downside 對玩家來說是可讀的（「我選了這個，下一波固定多 3 隻紅色小怪」），而不是隱藏在亂數池比例裡看不出來。

### 9.3 SmallEnemy Pattern 方向（示意顏色配置，非最終美術定案）

```txt
Red    — 前方 1x3 cleave
Orange — 自身周圍 3x3 puff
Yellow — 直線 1x4 突刺
Blue   — 短距 charge
Purple — 延遲爆炸 tile
Green  — corrupt land 遺留
White  — 快速小範圍連打
Black  — guarded / 裝甲變種
```

不需要每種顏色都是獨立 scene，SmallEnemy 讀取一個 pattern id 即可，顏色與 pattern 一對一綁定。

### 9.4 場上敵人全域上限

不對 ModeEnemy elite 單獨設存活上限；改用一個涵蓋所有敵人類型的全域同時存活上限：

```txt
max_concurrent_enemies = 12 + N
N = floor(wave / 5) * 4
```

超過上限時，多餘的 spawn 進入排隊，等場上有空位（現有敵人死亡）才補生成，不強制擠掉場上已存在的敵人。這條規則同時保護 SmallEnemy 的主力密度與 elite 數量比例，不需要對 elite 另外寫淘汰或去重邏輯。

---

## 10. 視覺語言與 Feedback 規範

這節是整份文件裡優先度被低估風險最高的部分，因此獨立成節，不埋在 Draft 裡。

### 10.1 敵人可讀性 Scaffold（低成本版，先於花招數量投資）

```txt
每個敵人狀態（Idle / Move / Prepare Attack / Attack）各一張四方向 sprite，先不做完整幀動畫
用 offset、squash/stretch、旋轉、閃光、windup VFX、attack VFX 補動作感
SmallEnemy 優先套用，確保後續 pattern 顏色與 telegraph 疊加時仍可辨識
```

### 10.2 事件分級（越重要的事件視覺越誇張）

```txt
Guard 命中（有防禦）→ 中等 hit flash、guard chip FX
Guard Break → 盾碎、hit stop、音效、震動
Dash 破盾 / Dash 背刺 → 大型 FX、慢動作、重擊音效
Stagger 期間爆發傷害（普攻 1.0x / Dash 2.0x）→ 依倍率分級的 hit flash
Execution Major 觸發的秒殺 → 最大強度 FX，必須與一般擊殺明顯不同
Corrupt Land tick → 持續但克制的視覺，不能搶過敵人 telegraph
```

### 10.3 底線

```txt
Telegraph 顏色 = 危險相位，不得與敵人本體顏色（pattern 標示）混用同一套色碼
Dash 命中成功 / 落空必須有截然不同的回饋
地形碎裂雖然允許雜亂，但地形本身不可與 hitbox 視覺混淆
```

---

## 11. MVP / 可宣傳 Vertical Slice 範圍

在完整 roadmap 之前，先鎖定一個「能剪 15-30 秒短片」的最小可展示切片，這不是最終 MVP，而是宣傳優先的最小子集：

```txt
1. Dash 命中大量破盾（6.1）+ 側背穿透傷害（6.2）+ Stagger 2x 爆發（6.3）可運作
2. Guard Shredder 與 Execution 兩個 Major effect 至少一版可動（6.4）
3. Chain Dash Major effect 至少一版可動
4. Infinite wave loop 雛形（不需要完整 milestone 曲線，能無限跑即可）
5. SmallEnemy 至少 3 種顏色 / pattern 可辨識
6. 多波 Tile Op 之後，地圖碎裂視覺明顯
```

這六項全部就緒即可對外釋出片段測試反應；不需要等 Weapon Class Variants、Tower reward cards、完整 sprite scaffold、6-8 種 pattern 全部做完。

---

## 12. 已拍板決策與剩餘開放問題

v0.3 給的是設計鎖定，v0.4 原本誠實列出「架構或數值還沒有明確答案」的地方；這節記錄後續拍板的結果，避免邊做邊即興出現互相打架的規則。

### 12.1 已拍板

- **瞬間破盾 / 瞬殺不是 baseline，是 Major effect**：Guard Shredder（背刺瞬間破盾）與 Execution（Stagger 瞬殺）正式收編為兩個獨立 Major，baseline 只有 6.1～6.3 的大數字。兩者不再重複，各自有清楚的獨特價值。
- **Chain Dash 與 Smash 互斥**：兩者共用同一個 exclusivity group，一個 build 不能同時持有兩者；透過 Major effect 的互斥群組機制強制執行，沒有 group 的 Major（例如目前唯一的 placeholder Major）永遠不會因為互斥被排除。兩個技能本身尚未實作，這裡先鎖定的只有規則。
- **Guard 上限不隨 milestone 成長**：milestone 只影響敵人 Def / HP / Damage，不影響 max_guard。因此 6.1 的 `max(quarter_guard, 16)` / `max(half_guard, 32)` 這兩個下限在整場 run 都維持有意義，不需要額外的隨波數校準規則。
- **場上敵人有全域上限，而不是針對 ModeEnemy elite 單獨設上限**：場上同時存活敵人數量上限為 `12 + N`，`N = floor(wave / 5) * 4`。超過上限的 spawn 進入排隊，等場上有空位再補生成。這個規則同時保護 SmallEnemy 主力密度與 elite 數量，不需要對 elite 另外寫淘汰邏輯。
- **無限模式目標曲線**：正常一輪抓「打到第 20 波陣亡」為基準難度，「打到第 30 波」視為高端 / 封頂表現，8.2 節的 per-wave 成長常數與 5-wave milestone 幅度都往這個目標校準。
- **Corrupt Land 與 Dash 的關係**：Dash 判定期間有 i-frame，經過 Corrupt Land 不觸發 tick 傷害；只有玩家非 Dash 狀態站在 / 走過該格才會計算 tick。不需要額外規則。
- **地形碎裂下限保護**：地形變動改為固定的 Tile Op——非 milestone wave 清完自動觸發一次，50% 機率位移 2 塊地、50% 機率移除 1 塊安全連通地，不再是可疊加的 reward 選項；每 5 波 milestone 清完固定給 Expand Land x10，當波不再額外執行 Tile Op。理論上長線是緩慢淨增長，不需要額外的「剩餘 land 過低禁用移除」保護規則。

### 12.2 已知先接受、暫不解決

- **Reward downside 文案與實際套用的一致性**：目前只有 Aggressive 分類的條目 downside 較明顯，但沒有機制讓玩家一眼看出「這個 reward 具體在跟我交易什麼」。這點先留在 `TODO.md` 的 Draft，不在這個階段強求解決。

### 12.3 仍待釐清

1. **Guard Shredder / Execution 是否對 ModeEnemy elite 生效**：兩者已經是要主動選的 Major，風險比原本當 baseline 時低很多，但仍需決定 elite 是否要有「免疫瞬殺/瞬破」標記，以及畫面上要不要區分。
2. **哪些 TODO 條目要先升到 Active，對齊第 11 節的六項切片**：目前 TODO 的 Draft 條目（Infinite Chaos Wave Mode、Major/Minor Build、Guard Hit SFX、SmallEnemy Pattern Director 等）彼此都合理，但沒有標出哪幾條是宣傳切片的必要路徑，建議先把對應到第 11 節六項的部分拆出來、優先推進到 Active。

---

## 13. 開發優先順序（對齊 TODO Milestone）

### Milestone 1 — 收斂現有 loop

```txt
固定 wave composition，不再是 support enemy 全隨機
Reward 選擇的 downside 文案先接受不完全一致（12.2），但至少 Aggressive 類要有基本標示
Terrain cadence 改為非 milestone wave 固定 Tile Op、每 5 波固定 Expand Land x10
套用場上敵人全域上限 `12 + floor(wave/5)*4`，超過排隊等 spawner
```

### Milestone 2 — 強化 combat feedback

```txt
Hit stop
Guard damage popup / shield chip feedback
Guard Break 大特效
Stagger 狀態明顯化
Dash 命中成功 / 落空的清楚回饋
```

### Milestone 3 — Reward 變成 build identity

```txt
Dash build / Normal attack build / Terrain control build / Risk pressure build / Survival build
PlayerRunBuild 架構落地，Major/Minor 效果不再直接改屬性
```

### Milestone 4 — Elite 與後期壓力

```txt
ModeEnemy 轉型為 elite，接上 milestone 排程
Boss wave 的「終局」概念取消，改為持續壓力曲線
SmallEnemy pattern 擴充到 6-8 種
```

---

## 14. 版本鎖定項目（v0.4）

```txt
Arena 為中大型動態網格（現況 16x16），非 6x6
玩家 free movement，不佔 grid occupancy
敵人與 elite 使用 grid-based tactical telegraph
SmallEnemy 是主力敵人，佔 spawn ≥ 60%，靠顏色/pattern 資料化擴充內容
ModeEnemy 是週期性 elite，不是傳統 boss，死亡不清場、不結束 run
Run 為 infinite wave survival，玩家死亡才結束
Reward 是 run 內容主體：Major ≤4 改規則，Minor 無限疊改數值
Dash 是清場核心動作，可被 Major 改變行為（Chain Dash / Smash 等）
Baseline Guard Damage：Front 8 / Side max(quarter_guard,16) / Back max(half_guard,32)，普攻與 Dash 共用
Baseline HP 穿透比例：Front 0 / Side 0.1 / Back 0.25；Stagger 期間爆發倍率：普攻 1.0x / Dash 2.0x
瞬間破盾（Guard Shredder）與瞬殺（Execution）不是 baseline，是需要主動選的 Major
Guard 上限不隨 milestone 成長，milestone 只影響 Def / HP / Damage
場上敵人全域上限為 `12 + floor(wave/5)*4`，超過排隊等 spawner，不對 elite 單獨設上限
無限模式目標曲線：正常一輪抓第 20 波陣亡，第 30 波視為封頂
地形只要求 land 連通，允許隨 Tile Op 逐漸碎裂；Tile Op 在非 milestone wave 清完自動觸發一次（50% 位移 2 塊、50% 移除 1 塊，不再是 reward 選項），Expand Land 每 5 波給 10 塊且取代當波 Tile Op
Dash 判定期間有 i-frame，不吃 Corrupt Land tick 傷害
命中仍用 hitbox / hurtbox，正側背仍用 attacker origin 相對 target facing 判定
視覺語言（顏色=pattern、telegraph 相位、Dash 回饋、Guard Break 事件）是混亂設計成立的前提，不可被犧牲
```

---

## 15. 術語表（新增/變更項目）

| 術語                       | 說明                                                                                           |
| -------------------------- | ---------------------------------------------------------------------------------------------- |
| PlayerRunBuild             | 玩家 run 內累積效果的儲存容器。已實作：reward effect 是各自獨立的物件（不再是單一 effect-type enum），套用後記錄進 run-scoped 的 applied-effect 儲存，Minor 效果的最終數值由此投影而來，Major 效果共用同一套儲存，已有上限 4 個與互斥群組檢查。尚未實作：Ability Override 與 Triggered Effect 這兩項技能行為改寫掛勾。 |
| Major Effect               | 上限 4 個，改變技能行為 / 規則（例如把 Dash 換成 Smash）；容量上限與互斥群組檢查已實作，目前僅有一個不改變任何行為的 placeholder Major |
| Minor Effect               | 無上限，改數值或小規則，可無限疊加                                                             |
| Ability Override（尚未實作） | Build 中決定當前技能實際行為型態的欄位（例如 dash_type）                                       |
| Triggered Effect（尚未實作） | 掛在特定事件（on_dash_hit / on_kill / on_stagger）上的效果清單                                 |
| Elite (ModeEnemy)          | 每 5 波出現的強化敵人，取代原本的 boss 定位，死亡不清場                                        |
| Guard Shredder             | Major effect：Dash 背後命中直接把目標 Guard 歸零並進入 Stagger                                 |
| Execution                  | Major effect：Dash 命中已 Stagger 的敵人直接秒殺，取代 baseline 的 2.0x 倍率                   |
| Guard Damage               | 命中造成的盾值傷害，baseline 為 Front 8 / Side max(quarter_guard,16) / Back max(half_guard,32) |
| HP Damage Bypass           | 命中角度決定的、隔著 Guard 仍能穿透到 HP 的傷害比例                                            |
| Stagger Burst Multiplier   | 敵人破盾後命中的 HP 傷害倍率，普攻 1.0x / Dash 2.0x                                            |
| Global Enemy Cap           | 場上同時存活敵人數量上限，`12 + floor(wave/5)*4`，超過排隊等 spawner                           |
| Chaos Density              | 混亂設計的核心變因：敵人數量、telegraph 密度、地形碎裂程度的綜合                               |
| Vertical Slice（宣傳切片） | 第 11 節定義的六項最小可展示子集，優先於完整 roadmap                                           |
