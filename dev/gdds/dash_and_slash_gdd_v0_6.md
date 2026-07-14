# Tickstrike 企劃書 v0.6

## 0. 文件定位

本文件是目前遊戲設計的單一閱讀入口。前半部描述 codebase 現在可執行的 Tick Arena；末章 `Planned Work` 收錄目前 `TODO.md` 與 active plan 尚未完成的產品方向。除該章明確標示的內容外，本文件中的規則均以現行實作為準。

本作仍在可玩切片階段：核心戰鬥、十波 demo、endless 延伸、run rewards、Ninja 與 Viking 戰鬥套件均已存在；正式角色選擇、永久進度、Coin、artifact 解鎖，以及後續 enemy mobility 尚未進入 production flow。

---

## 1. 企劃定位

Tickstrike 是一款玩家時鐘制的 grid arena action roguelite。系統骨架採用 roguelike 的「每個有效行動推進世界」，操作節奏與回饋追求 action game 的流動感，危險資訊則使用 tactics game 的 tile telegraph、面向與結果預覽。

### 1.1 核心體驗

```txt
順風：連續移動、連砍、使用 Mobility 穿場或破陣
危局：停止輸入，世界保持靜止；免費瞄準、閱讀 telegraph、規劃角度與落點
解題：用走位、Guard break、Mobility 或 build effect 打開局面
重新起速
```

核心張力是「流動 → 危機 → 靜止思考 → 解題 → 再流動」。玩家不需切換遊戲模式；輸入速度本身決定當下偏向動作或策略。

### 1.2 設計支柱

1. 玩家掌握時鐘：世界只在玩家完成會消耗時間的合法行動後前進。
2. Preview 與 telegraph 必須可信：顯示的格、倒數、落點與結果使用和實際結算相同的規則。
3. 一格一 actor：佔格、body block、攻擊來源與命中格必須清楚。
4. 少量敵人形成組合題：壓力來自角色互補、面向、空間與 committed attacks，而非單純堆疊數量。
5. 回饋採 action game 標準：hit stop、音效、震動、動畫與重大結果分級要讓棋盤判定仍具有打擊感。
6. Build 改變解題成本：Minor 疊加數值，Major 改變 Dash 的戰術連鎖；所有 reward 都只作用於當次 run。

---

## 2. Run 與 Arena

### 2.1 Run 流程

```txt
開始 Run
→ 進入 Wave
→ 清除所有已排程與存活敵人
→ Wave 完成
→ 選擇一個 Reward
→ 下一 Wave
```

死亡會結束 run。完成 Wave 10 會先記錄 demo completed，再顯示兩個選項：

- `End Run`：成功結束本次 run，顯示結果。
- `Continue Endless`：先領取 Wave 10 的 milestone reward，再進入 endless waves。

目前沒有 active-run save。離開應用程式或返回選單不會保存未完成 run。

### 2.2 Arena

- 邏輯 grid 為 12×12，起始可行走 land 為中央 10×10。
- 玩家與敵人各佔一格；敵人阻擋普通移動。
- 玩家沒有 contact damage，只有站在實際引爆的攻擊格才會受傷。
- 普通移動不可穿過敵人；Dash 可以穿越沿途敵人，但必須落在合法空格。
- 現行 run 使用穩定地形，不在波次之間隨機增減、腐化或搬動 land。

---

## 3. Tick 與輸入文法

### 3.1 世界推進

一次有效的 Move、Normal Attack、Mobility、Wait，或 Smash windup 預設消耗一個玩家行動並推進世界一個 tick。移動滑鼠與切換 Attack／Mobility mode 不消耗 tick；非法目標會被拒絕，也不推進世界。

每次世界推進依下列順序結算：

```txt
1. 玩家行動已完整結算，玩家位於行動後的新格
2. 倒數歸零的敵人 committed attack 對鎖定格引爆
3. 敵人狀態推進並取得 action energy；能量達標的敵人依序行動
```

敵人 speed 使用每 tick 累積 100 energy 的 scheduler。低於 100 的角色會跨 tick 累積，高於或等於 100 的角色可在該世界 tick 取得行動；staggered 或 recovering 的角色不行動，也不儲存能量。

### 3.2 操作

| 動詞          | 操作                                  | 時間        | 說明                                                          |
| ------------- | ------------------------------------- | ----------- | ------------------------------------------------------------- |
| Move          | WASD 點按或按住                       | 預設 1 tick | 4 向移動；按住以 0.24 秒 cadence 重複。                       |
| Normal Attack | Attack mode 下左鍵                    | 預設 1 tick | 滑鼠選擇 4 向，攻擊相鄰一格；按住以 0.32 秒 cadence 重複。    |
| Mobility      | 按住 Alt 進入 Mobility mode，左鍵確認 | 預設 1 tick | 執行目前角色固定的 Dash 或 Smash。放開 Alt 回到 Attack mode。 |
| Cancel        | 右鍵                                  | 0 tick      | 取消已 armed 的 Smash；已支付的 windup tick 不退款。          |
| Wait          | Space                                 | 1 tick      | 原地讓世界前進；可按住重複。                                  |

滑鼠只選擇方向或落點，瞄準永遠免費。HUD 上的互動會抑制同一個 mouse button 的遊戲動詞，避免點擊 UI 時誤攻擊。

### 3.3 Speed Meter

Move 與 Normal Attack 會填充共用 Speed Meter；100 點滿。當 meter 已滿時，下一次 eligible Move 或 Normal Attack 會消耗 meter 且不推進世界，行動本身仍正常結算。

- Ninja 基礎填充：每次 20。
- Viking 基礎填充：每次 10。
- 每層 Speed reward 額外增加 10。
- 單次填充上限為 75。
- Mobility 不以一般方式填充或消耗 Speed Meter；Chain Dash 可直接把 meter 設為 ready。

---

## 4. Player Combat 與 Character Class

### 4.1 共通戰鬥

- Normal Attack：相鄰一格、4 向、基礎傷害 20。
- 玩家無持續 facing；每次攻擊方向由游標決定。
- 玩家攻擊敵人的角度由 attack origin、目標格與敵人 facing 解算為 Front、Side 或 Back。
- Preview 必須顯示會命中的格、Mobility 路徑／落點，以及各目標的預測結果。
- Max Health reward 增加上限時，同時補回同量 current HP，但不超過新上限。

### 4.2 Ninja

Ninja 是目前 production run 的預設角色。

| 屬性            | 內容                                         |
| --------------- | -------------------------------------------- |
| 固定 Mobility   | Dash                                         |
| 基礎 Speed fill | 20                                           |
| Dash range      | 5 格，可由 Mobility Range 增加               |
| Dash cooldown   | 4 ticks，可由 Mobility Cooldown 降低，最低 1 |
| Dash damage     | 30，可由 Mobility Attack Damage 增加         |

Dash 沿 4 向直線前進，穿越路線上的敵人並對每個目標造成一次命中，最後落在路線上最近的合法目標格。Dash 是 Ninja 的解圍、Guard break、繞背與清場動詞。

### 4.3 Viking

Viking 的戰鬥資料、視覺與 Smash 已實作，可由 debug surface 切換測試；production run 目前仍固定從 Ninja 開始，正式選角與解鎖屬於 Planned Work。

| 屬性            | 內容                                         |
| --------------- | -------------------------------------------- |
| 固定 Mobility   | Smash                                        |
| 基礎 Speed fill | 10                                           |
| Smash range     | 3 格，可由 Mobility Range 增加               |
| Smash cooldown  | 6 ticks，可由 Mobility Cooldown 降低，最低 1 |
| Smash damage    | 30，可由 Mobility Attack Damage 增加         |

Smash 第一次確認會鎖定落點並支付一個 windup tick；下一次確認在落點周圍結算 3×3 攻擊。攻擊角度以 landing cell 為 origin，對每個受害者個別套用共通角度規則。改用其他動詞或右鍵可取消 prepared Smash，但 windup 已推進的 tick 不退款。

### 4.4 Class 契約

Character Class 固定自己的 Mobility identity。Reward 可以增加共通 Mobility 數值或附加相容效果，但不會把 Dash 替換成 Smash，也不會讓一個角色擲到另一個 Mobility 的 exclusive Major。

---

## 5. Enemy Combat

### 5.1 共通行為

- 敵人是 1×1 grid actor，依 energy scheduler 取得行動。
- 攻擊先 commit 並顯示 tile telegraph，再依 warning ticks 倒數引爆；commit 後不因玩家移動而重新瞄準。
- 敵人每次轉向受限，玩家可利用 Side／Back angle 與移動時間繞過 Guard。
- 敵人移動使用 grid occupancy 與 reservation；同一格不可同時存在兩個 actor。
- Guard break 會清空敵人的已儲存 action energy，進入 stagger，避免 recovery 後立即使用舊能量偷動。

### 5.2 現行 Roster

| 角色           | 戰術定位             | 現行行為                                                                                                                                                                 |
| -------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Thrust / Slash | 基礎近戰             | 共用 SmallEnemy 行為，以 authored tile pattern 形成直線或寬幅近戰；speed 75，轉向與追擊提供繞背窗口。                                                                    |
| Charge         | 直線 burst threat    | speed 100；與玩家對齊且完成轉向後，commit 最多 5 格 charge line，倒數後傷害仍站在線上的玩家並衝到最遠合法落點。                                                          |
| Ranged         | 後排空間壓力         | 使用 Small profile；維持 Manhattan distance 3–5，在玩家 commit 時所在格鎖定五格十字攻擊，不提供近戰 fallback。                                                           |
| Bomb           | 逼迫移位             | 無 Guard、speed 75；玩家進入周圍八格時，鎖定以自身 commit cell 為中心、Manhattan radius 4 的爆炸區；三 tick warning 後造成 50 damage 並自我死亡。                        |
| Mode           | Elite／Boss 行為骨架 | 每個 combat cycle 從 authored tile、area 或 charge attacks 中選擇一種；stagger 結束後進入 10 world ticks retaliation，期間新攻擊 warning 減少 1（最低 1）且傷害乘 1.25。 |

Wave 10 的 boss 目前使用 Mode-based placeholder。Boss role 與 Mode combat behavior 已可運作，但正式 boss identity、獨有招式與 presentation 尚不是本版內容。

---

## 6. Damage、Guard 與 Stagger

### 6.1 角度結算

| Hit angle | Guard damage | 未破 Guard 時的 HP bypass |
| --------- | -----------: | ------------------------: |
| Front     |            4 |                        0% |
| Side      |           16 |                       10% |
| Back      |           32 |                       25% |

目標沒有 Guard、已在 stagger、或本次命中直接 break Guard 時，該次攻擊造成完整 HP damage。攻擊已 staggered 目標時，Normal Attack 使用 1× stagger burst，Mobility 使用 2×。

### 6.2 Guard Profiles

| Role  | Base Guard | Wave 21 起每個 lethal tier 增量 |
| ----- | ---------: | ------------------------------: |
| Small |         32 |                              +8 |
| Heavy |         64 |                             +16 |
| Elite |         96 |                             +24 |
| Boss  |        128 |                             +32 |

Guard 在 base wave 1–20 維持 profile base。自 Wave 21 起，每五個 base waves 增加一個 lethal tier，沒有硬上限；enemy group 的 level offset 不會提高 Guard。

Guard break 預設造成 3 ticks stagger。Stagger 結束後有 5 ticks protection，期間 Guard damage 乘 0.5；Mode 另啟動 retaliation 規則。

---

## 7. Wave、Spawn 與 Enemy Level

### 7.1 資料驅動 Wave

WaveCatalog 包含十個 authored demo waves 與一個 endless template。每波定義：

- population cap；
- 依序處理的 group slots；
- group 的 start condition 與 spawn warning ticks；
- enemy group composition 與 placement grammar；
- 可選的 level offset 與 boss role。

一個 group 必須整組通過 population cap 與 placement admission 才能開始 spawn warning；不允許只生成部分 group。Warning 結束時若原格不再合法，spawner 依既定 replacement 規則尋找附近合法格。

### 7.2 Demo 節奏

| Wave | 主要教學／組合                                                    | Population cap |
| ---: | ----------------------------------------------------------------- | -------------: |
|    1 | Small                                                             |              3 |
|    2 | Ranged                                                            |              2 |
|    3 | Small + Ranged                                                    |              5 |
|    4 | Charge                                                            |              2 |
|    5 | Small + Ranged + Charge                                           |              5 |
|    6 | 依序加入 Small、Ranged、Charge groups                             |              6 |
|    7 | 依序加入 Ranged、Small、Charge groups                             |              7 |
|    8 | 加入 Bomb                                                         |              8 |
|    9 | 完整一般 roster 組合                                              |              9 |
|   10 | Boss-only Mode placeholder，2-tick spawn warning，level offset +3 |              1 |

Wave 11 起重複使用包含 Charge、Ranged、Small、Bomb 的 endless template，population cap 為 10；敵人實際 level 隨 base wave 繼續上升。

### 7.3 Enemy Level

每個 spawned enemy 的 final level 為 base wave 加上 group slot 的非負 level offset。EnemyData 提供 Level 1 HP、damage、Defense 與 Guard role；progression profile 將 final level 投影成當前數值，不修改 authored source data。

- HP 與 damage 使用乘數成長，Defense 使用 flat growth。
- Level 10 起加入較強的 lethal curve term。
- 所有成長皆無隱藏 level cap 或輸出 cap。
- Guard 只讀 base wave 與 Guard profile，不讀 group level offset。

---

## 8. Rewards 與 Run Build

### 8.1 Reward Cadence

- 一般 completed wave：從符合資格的 Minor 中提供三選一，每張一層。
- 每第三個 completed wave：提供 milestone 三選一；第一格固定為 Minor ×2，另外兩格優先為 Major，不足時使用彼此不同的 Minor ×2 補滿。
- Wave 10 選擇 `Continue Endless` 後仍會先領取其 milestone reward。
- Reward 稀有度由 completed-wave cadence 決定，不由該波是否存在 Boss 決定。

### 8.2 Build Rules

- Minor 可疊加到各自 max stacks，主要投影 Normal Attack Damage、Mobility Attack Damage、Speed、Mobility Cooldown、Mobility Range 與 Max Health。
- Major 是 unique legendary effect；run 最多持有四個 Legendary。
- Artifact 必須同時通過 min wave、rarity、stack、ownership、exclusivity、Legendary capacity 與 required Mobility eligibility。
- Build 只在當次 run 內有效，restart 會清空。

### 8.3 現行 Artifact Pool

| 類型             | Artifact          | 效果                                                                                                                                          |
| ---------------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Minor            | Sharpened Edge    | 每層 +10 Normal Attack damage。                                                                                                               |
| Minor            | Fleet Step        | 每層 +1 Speed，換算為每次 +10 Speed Meter fill。                                                                                              |
| Minor            | Impact Dash       | 每層 +20 Mobility Attack damage；目前 display name／文案仍使用 Dash 名稱。                                                                    |
| Minor            | Light Footwork    | 每層 -1 Mobility cooldown，最低 1 tick。                                                                                                      |
| Minor            | Extended Mobility | 每層 +1 Mobility range。                                                                                                                      |
| Minor            | Vital Spark       | 每層 +20 Max Health，取得時同步補回 current HP。                                                                                              |
| Major, Dash-only | Guard Shredder    | Back-angle Dash hit 立即 break Guard。                                                                                                        |
| Major, Dash-only | Execution         | Dash 命中已 staggered 目標時立即擊殺。                                                                                                        |
| Major, Dash-only | Chain Dash        | Dash 命中符合 Back、guard break、staggered 或 kill 任一條件時，清除 Dash cooldown 並把 Speed Meter 設為 ready；觸發該次 Dash 仍正常推進世界。 |

目前 production registry 沒有 curse、terrain reward 或 pressure artifact。

---

## 9. Telegraph、Preview 與 Feedback

### 9.1 敵人資訊

- Warning 與 charge phase 必須顯示 committed attack 的實際危險格。
- Charge 額外顯示 committed destination；spawn warning 顯示即將佔用的格與剩餘 ticks。
- 攻擊引爆只檢查 committed cells，不追蹤玩家的新位置重新置中。
- 玩家走出 committed danger cells 即安全；仍在其中即受擊。

### 9.2 玩家 Preview

- Attack mode 顯示 Normal Attack 方向與結果。
- 按住 Alt 時顯示目前角色 Mobility 的路徑、落點與命中範圍。
- armed Smash 即使離開 Mobility mode，仍保留已鎖定的落點與範圍提示，直到釋放或取消。
- 每個預測受害者顯示 angle 與重大結果，包括 `BURST`、`BREAK`、`KILL`、`SHREDDER`、`EXECUTION`。
- 玩家 preview 使用與敵人 danger 不同的色系。

### 9.3 Action Feedback

Normal hit、Guard hit、Guard break、stagger burst、kill 與 Major trigger 使用不同級別的文字、VFX 與 SFX。高價值結果必須比普通 chip damage 更大聲，但不能遮蔽下一個 tick 所需的棋盤資訊。

---

## 10. Planned Work

本章描述目前仍在 `TODO.md` 或其 linked plans 中的方向，不代表已實作或已承諾最終數值。實際施工時以對應 plan、spec 與當時 codebase 為準。

### 10.1 Enemy Mobility 與 Forced Displacement

- 將 Charge 改成完整的 committed collision attack：鎖定五格路線，區分 Environment、可移動碰撞物與 Player，處理傷害、側向位移、push 與 pinned double damage。
- 新增 DashEnemy，從最遠五格 cardinal approach 鎖定玩家背後落點；落點在引爆前被佔用時整次取消，不重新瞄準。
- 建立共用 forced-displacement 與 occupancy refresh seam，供 Charge、DashEnemy、Viking Smash knockback 與未來 spawn displacement 重用。
- 在共用 seam 穩定後，評估 warned spawn cell 被玩家佔用時改為先生成再位移玩家；目前維持安全 replacement placement。

### 10.2 Meta Progression

- 新增 save-backed Coin；只有 Death 或 `End Run` 形成 terminal settlement，且只計算 completed waves。每第五個 completed wave 另有 bonus，結算必須 idempotent。
- Ninja 首次完成 Wave 10 時立即永久解鎖 Viking，即使選擇 Continue Endless 也不會遺失。
- Main Menu 新增已解鎖角色選擇；locked／invalid selection 不得進入 gameplay。
- 使用 Coin 永久解鎖 authored artifacts。永久解鎖只增加候選 pool，run-time eligibility 仍完整適用。
- 不保存 active run，也不讓永久進度直接增加基礎戰鬥數值。

### 10.3 Combat Content Candidates

- 為 Dash 與 Smash 增加更多 Mobility-specific Majors；效果擴充 active Mobility，不恢復 payload replacement。
- 初始 classes 維持一格 cardinal Normal Attack；待 Ninja／Viking class identity 通過 playtest 後，再研究 line、arc 或 wide variants，並先統一 preview、commit 與 auto-attack-on-move footprint。
- Samurai 延後到 fixed-Mobility class model 穩定後；需要自己的 Mobility identity，guard／counter 是否值得成為新 combat verb 尚未拍板。
- 研究 forced three-choice curse offers，以改變玩法的 mutator 取代隱藏 stat pressure；候選包含半血開波、Mobility cooldown／damage trade、action drain／lifesteal、Normal／Mobility Guard damage trade，以及不計入 wave completion 的 Nemesis hunter。

### 10.4 Stable Arena 的後續內容

- 維持 10×10 stable land base，不恢復每波隨機增減地形。
- 研究額外 obstacle grid，作為未來 map pressure 與 Corrupt Land 類危險格的承載層。
- 障礙物與基本 enemy spawn weighting 穩定後，再研究 Fortified Land、Tower、Archer Tower 等 player-owned board-pressure reward cards。
- Reward economy 後續可加入 card rarity、weighted rolls、deck-building economy 與 final card art。

### 10.5 行為與架構 Follow-ups

- 檢查 Enemy Idle／Reposition 在 reservation loss 或 blocked first step 時的空轉：決定一次 funded action 是否應在同 tick 內完成 decision 與 movement／turn／commit，並加入立即 replan。
- 檢查新生成敵人的第一個 funded action，避免只做 FSM transition 而視覺上停在 Idle 一整輪。
- 目前 player Move、Normal Attack 與 Smash windup 由 TickActionController 直接 dispatch，Smash 只用單一 armed flag；在出現更多 multi-phase player verbs 前維持此輕量結構，新增第二個 ad-hoc state bool 前必須重新評估 StateMachine ownership。

---

## 11. 術語表

| 術語                | 說明                                                                                             |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| Player-Clocked Tick | 世界只在玩家完成會消耗時間的合法動詞後前進。                                                     |
| Free Action         | 行動完整生效但不呼叫 world advance；目前來源是已滿 Speed Meter 的 eligible Move／Normal Attack。 |
| Committed Attack    | 敵人在 warning 開始時鎖定攻擊格、路線或落點；引爆前不重新瞄準。                                  |
| Preview-is-truth    | 玩家預覽與實際結算共用規則，顯示的格與結果必須能逐字執行。                                       |
| Body Block          | Actor 佔格阻擋普通移動；Ninja 使用 Dash 作為主要解圍方式。                                       |
| Mobility            | Character Class 固定擁有的特殊移動／攻擊動詞；目前為 Ninja Dash 與 Viking Smash。                |
| Speed Meter         | Move／Normal Attack 填充的 100 點 meter；滿時使下一個 eligible 行動成為 Free Action。            |
| Guard Profile       | 依 Small、Heavy、Elite、Boss role 定義 base Guard、lethal-tier growth 與 stagger protection。    |
| Enemy Level         | Base wave 加 group level offset，用來投影 HP、damage 與 Defense；不直接提高 Guard。              |
| Spawn Group         | 一組必須共同通過 cap 與 placement admission 的 enemy entries。                                   |
| Demo Completion     | Wave 10 實際清除時立即成立的 run flag，之後才顯示 End Run／Continue Endless。                    |
