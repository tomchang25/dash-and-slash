# Dash and Slash：Player-Clocked Tick Arena 企劃書 v0.5（草稿）

版本定位：取代 v0.4。本版把玩家收進 grid，全遊戲統一為「玩家時鐘制 tick」；戰鬥身分系統（telegraph、面向、Guard、reward build）全數沿用。
文件目的與草稿聲明：本版寫於 tick 戰鬥 grey-box 原型驗證**之前**，是刻意的例外——正常流程是實證後才改設計真值。原型結論可能修改本文件任何段落，§11.3 明列留待原型的項目。原型實證與本文件衝突時，以實證後的修訂為準。

---

## 0. 與 v0.4 的差異（先講清楚，避免文件互打架）

| 項目             | v0.4                                       | v0.5                                                                                                                           |
| ---------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| 玩家操作         | 即時自由移動，不佔 grid                    | Grid actor，佔 1 格，合法輸入預設推進 1 tick；顯性 free action 可退款                                                          |
| 時間結構         | 連續時間，敵人量化                         | 玩家時鐘制：世界只在玩家行動時前進，時間域統一                                                                                 |
| 體感定位         | Brotato 式爽快混亂                         | 傳統 roguelike 骨 + 動作遊戲皮 + 戰棋可讀性工具箱（對標 NecroDancer / Jupiter Hell 的體感，不是 Into the Breach 的全資訊解謎） |
| 命中判定         | hitbox / hurtbox                           | Grid 判定：攻擊格 overlap 目標格                                                                                               |
| 正側背           | attacker body center 相對 target facing    | attacker origin tile 相對 target facing（同一規則量化）                                                                        |
| 敵人壓力         | 數量密度（全域上限 12 + floor(wave/5)\*4） | 少而精（同場目標 3-6 隻），組成與地形幾何為壓力旋鈕                                                                            |
| Guard / 傷害數值 | §6 數值表                                  | 原封沿用，不重調                                                                                                               |
| Reward 架構      | Major ≤4 / Minor 無限 / store 投影         | 原封沿用，新增 general Speed、Mobility Cooldown、條件式 Mobility Free Action Major                                             |
| Elite            | 每 5 波 ModeEnemy，死亡不清場              | 沿用定位，行為 tick 化                                                                                                         |

之後 v0.4 與 v0.5 有衝突，一律以 v0.5 為準；v0.4 僅保留作歷史參考。

改版根因（記錄下來避免重蹈）：v0.4 的「玩家連續時間 + 敵人量化時間」混種讓兩邊都無法真正威脅或回應對方——敵人只能在 grid center 取樣玩家所以顯得笨重，玩家側移半格就閃過 telegraph 所以讀招沒有成本，繞背零成本所以面向系統退化。本 codebase 的戰鬥系統（面向、正側背倍率、Guard Points、tile offset 攻擊資料、telegraph 相位、grid reservation）本來就是戰棋系統，v0.5 是讓玩家操作層歸位，不是重做戰鬥。

---

## 1. 企劃定位

一款玩家時鐘制的 grid arena 動作 roguelite。骨架是傳統 roguelike（每個輸入推進世界一拍），皮是動作遊戲（連發輸入、snappy 動畫、打擊回饋），可讀性工具箱來自戰棋（tile telegraph、面向、行動預告）。

### 1.1 核心體驗迴圈

```txt
順風：按住方向鍵衝刺、連砍、dash 穿場 → 它是動作遊戲
危局：手一停，世界靜止，免費瞄準、讀 telegraph、算繞背路線 → 它是戰棋
解完題 → 再次起速
```

「流動 → 危機 → 靜止思考 → 解題 → 再流動」的張力循環是核心體驗；玩家自己控制遊戲當下是哪個 genre。這同時滿足策略性與即時互動——不是各打五折，而是讓玩家在兩端之間自由滑動。

### 1.2 Run 型態

沿用 v0.4：infinite wave survival、清波 → 三選一 reward → 下一波、玩家死亡才結束。改變的是波內戰鬥的時間結構，不是 run 結構。

### 1.3 「一個 Run 有趣」的成立條件

每一步都是一個看得懂的小謎題，而 build 改變的是各種解法的價格。面對同一組敵人：硬拆正面、花兩步繞背、dash 穿場、引誘 charger 撞牆、把敵人引到危險地形——這些選項同時存在，Major effect 決定哪個便宜。這個「有趣」不依賴 meta，不依賴無限內容量。

---

## 2. 核心設計支柱

### 2.1 全遊戲只有一種時間貨幣

任何玩家輸入（移動 / 普攻 / 機動技 / 等待）預設讓世界前進 1 tick；移動滑鼠（瞄準）永遠不消耗時間；非法輸入軟性拒絕、不消耗 tick。例外只能是顯性 free action：Speed meter 已滿時的下一個 eligible 移動 / 普攻，或 Mobility Free Action Major 讓當次成功機動攻擊退款。「慢」不藏在成本乘數裡，而是攤開成顯性 windup 回合。這條契約讓「還有 N 回合」永遠等於「你的任何 N 個會推進世界的輸入」——telegraph 在數學上不可能說謊，而不是靠 UI 補救。

### 2.2 Telegraph 與 Preview 永不說謊

整個系統是確定性的，可完整前瞻模擬：

```txt
敵人 telegraph 以「玩家行動數」計數，顯示永遠是模擬真值
玩家 preview-is-truth：攻擊方向、dash 路徑與落點、smash 範圍，按下瞬間逐字執行畫面所示
Preview 同時顯示解算後果：落地 ghost 與每個受害者的角度/結果徽章（chip / BREAK / KILL），由解算共用的同一套確定性規則預先算出——只給幾何不給後果的預覽等於沒有預覽（原型實測結論）
玩家 preview 用玩家色系，與敵人危險色系嚴格分離
```

### 2.3 判定必須可信（v0.4 §2.3 的量化版）

敵意 = telegraph 格；命中 = 攻擊格 overlap 目標格；正側背 = attacker origin tile 相對 target facing。走出紅格必安全，站在紅格必挨打——引爆判定鎖在 telegraph 標的格上，檢查玩家行動後的新位置。

### 2.4 打擊回饋照動作遊戲標準做

v0.4 §10 的視覺語言與事件分級原封沿用，且地位升高——hit stop、震動、破盾大事件是「這不是棋盤遊戲」的主要證詞。滑向純戰棋感的三個失守點要守住：資訊呈現一瞥可讀而非值得研究、敵人少而快而非多而慢、回饋照動作遊戲標準。

### 2.5 Reward 仍是內容主體

Major ≤4 改規則、Minor 無限疊改數值、run-scoped store 投影架構原封沿用。新框架下 build 的爽感從「數值堆到失控」升級為「骨牌式連鎖是玩家用腦算出來的」——dash 擊殺接免費 dash 的一條龍清場，比純數值檢查更耐玩。

---

## 3. Tick 系統（新）

### 3.1 每 tick 解算順序

```txt
1. 玩家行動完整解算（移動 / 普攻 / 機動技 / 等待；預設 1 tick，顯性 free action 可讓當次行動不推進世界）
2. 倒數歸零的敵人攻擊引爆——判定鎖在 telegraph 標的格，對玩家的新位置檢查
3. 敵人移動、面向更新、開新 telegraph；地形持續傷害在此階段結算
```

順序寫死，沒有模糊空間：玩家永遠先手，感受上公平；敵人之間的移動衝突沿用現行 grid reservation 優先權系統。

### 3.2 佔格規則

一格一 actor。敵人佔格會擋玩家的普通移動——grid 上的 body block 乾淨無 jank，「被包圍」成為真實威脅；Dash 是解圍閥，穿過敵人佔格、落在路線上最近的合法空格。玩家受擊 = 玩家所在格被引爆，沒有 contact damage。敵人之間的佔格規則沿用現行系統。

### 3.3 速度模型：底層 energy、表層量化

底層是 energy/cost 骨架（每個 actor 有 speed 欄位，行動照 energy 結算），但對玩家暴露的永遠只有 tick 一種貨幣。玩家 speed 收斂成兩個 Minor 投影和一個 Major 級時間退款：

| 概念                 | 實作                                                                      | 疊加方式                                                  |
| -------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------- |
| Speed                | 共用充能條：只有移動與普攻充能 / 消耗；滿了下一個 eligible 動作不推進世界 | Minor 提高充能率，移動與普攻暫時不拆兩條 speed            |
| Mobility Cooldown    | 機動槽冷卻 ticks（Dash / Smash 讀同一個 reduction，各自保留 base）        | Minor 每層 −1 冷卻，下限 1                                |
| Mobility Free Action | 機動攻擊若 kill / break guard / back hit，當次 action 本身不推進世界      | Major；同一次 attack 判定最多退款一次，可連續 action 觸發 |

敵人快慢用同一套骨架：慢怪每 2 tick 一動、快怪一 tick 兩動，意圖 icon 明示行動節奏。硬規則：**敵人雙動（玩家被減速側）必須視覺大聲**——兩段式預覽箭頭 + 專屬音效。加速自己是爽感，敵人加速是威脅，威脅側的可讀性投資加倍。

放棄的東西（有意識的交易）：連續值攻速縮放（沒有「+7% 攻速」），也暫時不做 windup reduction。Smash 是目前唯一玩家 windup，且只有 1 tick；在內容量不足時先做 reduction 只會抹掉 Smash 的 tradeoff。在「模擬豐富」和「telegraph 永不說謊」之間，本作永遠選後者。

### 3.4 Windup（顯性前隙）

重動作 = 顯性 windup：按下起手（1 tick，自身 windup telegraph 亮起、目標格亮起）→ 下一個輸入釋放；改按其他動詞 = 取消起手，已花的 tick 不退款——維持「慢動作拆成公開 tick，不藏成本乘數」的零隱藏成本原則。連發輸入整合：按住 = 連發脈衝第一下起手、第二下釋放，「按住 = 兩拍一擊」自然成立。

Windup 與 Stagger 的咬合：staggered 敵人不會移動，所以重擊收頭吃不到走位風險——「破盾 → 上重擊」從數值倍率升級為真正的戰術結構。

---

## 4. 輸入文法

### 4.1 雙通道契約

```txt
滑鼠 = 選參數（方向 / 落點）。移動滑鼠永遠不消耗 tick。
按鍵 = 執行動詞。任何合法動詞按下去，世界預設前進 1 tick；顯性 free action 會在結算後改成不推進世界。
非法目標按下去 = 無效 + 軟性拒絕回饋，不消耗 tick。
```

因為瞄準免費，「想快就按住連走連砍、想算就停下來慢慢瞄」不需要任何系統妥協。

### 4.2 動詞插槽

| 插槽                    | 按鍵                           | 滑鼠的作用                                  | 消耗                                           |
| ----------------------- | ------------------------------ | ------------------------------------------- | ---------------------------------------------- |
| 移動                    | WASD 點按 / 按住連走（約 7Hz） | 無                                          | 預設 1 tick；Speed meter 可退款                |
| 普攻                    | 左鍵                           | 決定攻擊方向（量化到 4 向，武器形狀跟著轉） | 預設 1 tick；Speed meter 可退款                |
| 機動槽（Dash 或 Smash） | 右鍵 / Shift                   | 決定落點                                    | 預設 1 tick；Mobility Free Action Major 可退款 |
| 等待                    | Space                          | 無                                          | 1 tick                                         |

Perk 換的是插槽的內容物（ability override），按鍵、瞄準方式、預覽文法永不變——玩家學一次「滑鼠指、按鍵發」，build 怎麼變手的記憶都不用重練。未來任何新 Major 技能只要能表達成「一個落點/方向 + 一格預覽」就能塞進機動槽，零新輸入教學。

輸入流暢度規格（回合制手感 = 輸入流暢度，不是時間系統）：輸入 buffer 1 動作（tween 中按下一步排隊）、移動 tween ≤100ms 配 squash/stretch、動畫永不鎖輸入、敵人動畫與玩家並行播放。手把：右搖桿 = 游標（方向 + 推桿幅度 = 距離）、肩鍵 = 動詞，同一套文法直接映射。

### 4.3 幾何

4 向移動、無斜角——讓「背後」的幾何乾淨（面向 = 4 向，back = 正對面扇區）。玩家無 facing，攻擊自由選向；面向系統的深度全部放在敵人身上。斜向移動 / 斜向 dash 保留為未來 perk 空間。

---

## 5. Entity 規格

### 5.1 Player

Grid actor、佔 1 格、無 facing。動詞見 §4.2。Run Build 沿用 v0.4 §4.1 的容器（Major ≤4、Minor 無限、ability_overrides、triggered_effects），其中 ability_overrides 與 triggered_effects 由本版的機動槽與 dash 觸發 Major 首次落地為真實內容。

### 5.2 敵人（行為 tick 化）

敵種定位沿用 v0.4（SmallEnemy 主力 + PuffEnemy / ChargeEnemy + ModeEnemy elite），行為全面 tick 化：

```txt
所有狀態計時從秒數改為 tick 計數；telegraph 倒數以玩家行動數計
面向 + 每 tick 轉向上限（如 90°）= 繞背深度旋鈕——慢轉速可繞、快轉速要靠 dash 或 stagger
windup tick 數 = 難度旋鈕（1-tick 快招 vs 3-tick 大招）
攻擊 pattern 維持 tile offset 資料化，attack executor 架構沿用
```

同場敵人目標 3-6 隻。v0.4 的全域上限公式 `12 + floor(wave/5)*4` 廢止，新上限公式留待調參——tick 世界裡每隻敵人是謎題元件，密度超過可讀性就是噪音，壓力改由組成與幾何供給。

### 5.3 Elite（ModeEnemy）

沿用 v0.4 §4.3 定位：每 5 波出現、死亡不清場、不結束 run。行為 tick 化與出場排程細節在 rework Phase 6 重校。

---

## 6. 命中、方向與傷害判定（數值沿用 v0.4 §6）

- 命中：攻擊格 overlap 目標格。
- 方向：attacker origin tile 相對 target facing；dash 命中時 origin = 玩家進入目標格前所在的格（= 進攻方向）。
- Guard Damage：Front 8 / Side `max(quarter_guard, 16)` / Back `max(half_guard, 32)`，普攻與 dash 共用。
- HP Damage Bypass：Front 0 / Side 0.1 / Back 0.25。
- Stagger Burst Multiplier：普攻 1.0x / Dash 2.0x。
- Guard Shredder（背刺瞬破）與 Execution（Stagger 瞬殺）仍是 Major effect，不是 baseline（v0.4 §6.4 原封沿用）。
- Guard 上限不隨 milestone 成長；milestone 只影響 Def / HP / Damage（沿用）。
- Smash 的方向判定：以 landing cell 作為 attack origin，對範圍內各目標套用同一規則，不另設無方向特例——是否改為固定無方向留待原型與調參（§11.3）。
- SFX / Feedback 對應沿用 v0.4 §6.5。

---

## 7. Dash / Smash / Build

### 7.1 Dash（機動槽預設）

順發、直線 4 向、5 格內落點由游標選定（受阻擋與佔格 clamp，落在路線上最近合法空格）、穿過沿途敵人並全部命中、冷卻以 tick 計。Dash 是解圍 / 破盾 / 清場三位一體的核心動詞，也是佔格 body block 規則的官方解圍閥。

### 7.2 Smash（第一個換槽 Major）

3 格內選落點 + 3x3 AoE，windup 1 tick（按下起手 → 敵人動一拍 → 下一輸入釋放）。交易讀法：**放棄瞬發機動，換取延遲一拍的範圍破盾**。與 Chain Dash 互斥（exclusivity group，機制已實作、沿用）。

### 7.3 Major / Minor

沿用 v0.4 §7 分層。新增：Speed Minor（移動 / 普攻共用充能）、Mobility Cooldown Minor（機動槽共用冷卻 reduction），以及 Mobility Free Action Major：機動攻擊若造成 kill、guard break 或 back hit，當次 action 本身不推進世界。Chain Dash 與其他追加 Major 是 rework 完成後的後續內容，不在轉換範圍。

---

## 8. Wave / Reward / 地形

沿用 v0.4：run 迴圈結構、三選一 reward 與三種 profile、Tile Op 固定節奏（非 milestone 波清完自動觸發一次）、每 5 波 Expand Land x10、milestone 成長維度（Def / HP / Damage，不含 Guard）、land 連通性硬規則。

本版重校項目（rework Phase 6）：

```txt
wave 成長常數全面重調（tick 節奏下的難度曲線與即時版不可比）
同場敵人上限公式（目標 3-6 隻同場）
arena 尺寸（16x16 對 1 格/tick 的移動可能過大，dash 5 格是主要位移手段）
Corrupt Land：玩家非 dash 狀態於解算第 3 階段站在該格時扣血；dash 穿過不觸發（沿用 i-frame 精神的 tick 翻譯）
```

地形在 grid 玩家下地位升級：碎地直接改變可走空間與 dash 線，Tile Op 與 Expand Land 從背景噪音變成關卡設計本身——這是 pivot 讓既有系統增值最多的一塊。

---

## 9. 視覺語言與 Feedback 規範

v0.4 §10 原封沿用（低成本敵人可讀性 scaffold、事件分級、底線三條），新增兩條硬規則：

```txt
玩家 preview 色系與敵人 telegraph 危險色系嚴格分離（自 v0.4 §10.3 升級為硬規則，因為玩家 preview 從偶發變成常駐）
敵人雙動 / 加速行動的預告必須大聲：兩段式預覽 + 專屬音效（§3.3）
```

---

## 10. 驗證閘門與可展示切片

### 10.1 Grey-box 閘門（先於一切）

隔離場景、灰方塊、兩種敵人（慢轉速近戰 + 2-tick charger）。kill criteria：「引誘 charger、側移、繞背一刀」感覺是賺來的動作爽感，而非選單戰棋。**閘門已於 2026-07-05 通過（go）**——實測結論「明顯更像遊戲而非測試專案」，原型 plan 已歸檔至 `dev/docs/archived/tick_combat_prototype.md`，轉換工程由 rework plan 接手。

### 10.2 閘門後的可展示切片

```txt
1. Tick 戰鬥全迴圈（wave / reward / 死亡重開）可玩
2. Smash / Guard Shredder / Execution 三個真 Major 可動
3. Speed meter、Mobility Cooldown、Mobility Free Action Major 可動，且任何 telegraph 顯示與實際解算零偏差
4. 同場 3-6 敵人的組成壓力曲線初版
```

開發順序與 phase 切分由 `dev/docs/plans/tick_combat_rework.md` 管理，本文件不重複。

---

## 11. 拍板記錄

### 11.1 本版新拍板

- 合法輸入預設推進 1 tick、顯性 free action 可退款的時間契約與三階段解算順序（§3.1）
- 統一行動成本；「慢」= 顯性 windup；取消不退 tick（§3.4）
- 雙通道輸入、動詞插槽、preview-is-truth（§4）
- 4 向移動、玩家無 facing、一格一 actor、敵人擋普通移動、dash 穿佔格落空格（§3.2、§4.3）
- 底層 energy 骨架、表層 tick 單一貨幣、Speed meter / Mobility Cooldown / Mobility Free Action 的顯性速度模型（§3.3）
- Dash 順發 / Smash windup 1；Chain Dash 與 Smash 互斥沿用（§7）
- 敵人少而精（同場 3-6 目標），密度讓位給組成與幾何（§5.2）
- 轉換策略：場景層（engine / input / player / arena root）為新建；共用戰鬥程式（敵人全家、wave 系統）自 rework phase 2 起**原地 tick 化**，不做 tick 前綴分叉——舊 arena 屆時停止運作但不刪，回滾依靠版本控制與 baseline 對照 build，cutover 時才清除殘骸（rework plan）

### 11.2 沿用 v0.4 不變

- Guard Damage / HP Bypass / Stagger 倍率全數值；Guard Shredder 與 Execution 為 Major；Guard 不隨 milestone 成長
- Reward store 架構（Major ≤4、互斥群組、Minor 無限、投影管線）
- Tile Op / Expand Land 節奏、land 連通性、milestone 成長維度
- 視覺語言與事件分級（§9 另加兩條）

### 11.3 留待原型與調參

1. Speed meter 的最終充能曲線與 cap；Phase 05 先交付最小可讀 HUD，Phase 07 統一做 HUD refactor 與 stats table。
2. windup 取消是否另加懲罰（目前：只損失已花的 tick）。
3. preview 常駐密度：普攻方向 + dash 路徑全常駐低透明，或按需顯示——grey-box 用手感回答。
4. arena 尺寸與同場敵人上限公式。
5. Smash 方向判定維持統一規則或改固定無方向。
6. wave 成長常數全面重校；「第 20 波陣亡 / 第 30 波封頂」目標曲線是否沿用待定。
7. Guard Shredder / Execution 是否對 elite 生效（v0.4 §12.3 遺留，繼續留待實測）。
8. 結果徽章的文字密度：smash 同時蓋到多隻時是否只保留 BREAK / KILL 級標籤、chip 級只留括框（原型遺留，正式版試玩再定）。
9. hold-to-aim 備案：若結果預覽仍不足以支撐單鍵 dash 的預知感，改為「點擊瞬發、按住 ≥0.15s 鎖定瞄準、放開執行」，不採 mode 切換（原型階段已否決 modal 輸入）。
10. 近戰追擊壓力第二刀：若 speed 75 後被圍仍過悶，調攻擊後隙 1→2 加大懲罰窗口，而不是繼續降速。

---

## 12. 術語表（新增 / 變更項目）

| 術語                    | 說明                                                                               |
| ----------------------- | ---------------------------------------------------------------------------------- |
| Player-Clocked Tick     | 玩家時鐘制：世界只在玩家執行會推進世界的動詞時前進，free action 是顯性例外         |
| Tick                    | 一次會推進世界的玩家輸入所產生的世界時間單位；全遊戲唯一對玩家暴露的時間貨幣       |
| 三階段解算              | 玩家行動 → 歸零攻擊引爆（對新位置）→ 敵人移動與新 telegraph                        |
| Windup                  | 顯性前隙：起手佔 1 tick 並亮出自身 telegraph，下一輸入釋放，改按他鍵取消不退款     |
| Speed Meter             | 移動與普攻共用的速度收益：充能滿時下一個 eligible 移動 / 普攻不推進世界            |
| Mobility Free Action    | Major 級時間退款：機動攻擊若 kill / break guard / back hit，當次 action 不推進世界 |
| Energy 骨架             | 底層速度結算系統；對玩家永遠隱藏，只透過 tick 行為表現                             |
| 機動槽（Mobility Slot） | 玩家的可替換動詞插槽，預設 Dash，可被 Major 換成 Smash 等                          |
| Preview-is-truth        | 玩家側預覽按下瞬間逐字執行，與敵人 telegraph 永不說謊同級的硬規則                  |
| Body Block              | 敵人佔格阻擋玩家普通移動；dash 為官方解圍閥                                        |
| 雙動預告                | 敵人在玩家單一行動內行動兩次時的強制大聲預警                                       |
