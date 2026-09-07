# LAHOUE — GEMINI / ANTIGRAVITY HANDOVER

Ngày xuất: 2026-08-17

## 0. MỤC ĐÍCH

Tài liệu này dùng để chuyển toàn bộ context quan trọng của dự án LaHoue từ ChatGPT/Codex sang Gemini/Antigravity.

**Source of truth về thiết kế:** Master Plan bên dưới.
**Source of truth về trạng thái code hiện tại:** phần "Trạng thái repository hiện tại", vì file audit cũ có thể phản ánh trạng thái trước khi các Phase 1–7 được implement.

Không được rebuild project từ đầu.

---

# 1. TRẠNG THÁI HIỆN TẠI

Project:
- Tên: LaHoue
- Engine: Godot 4.7.1
- Path local: `D:\Game\LaHoue`
- Git branch: `main`
- Git remote: `origin/main`
- Repository đã được phát triển tuần tự bằng Codex.
- Quy ước code: file, folder, biến, hàm, node và identifier viết thường.

## Các phase đã hoàn thành

### P0.1 — Player Foundation
Đã implement player foundation, movement/camera/interaction và các nền tảng liên quan.
Có commit riêng.

### P0.2 — Save/Load Robustness
Đã implement save/load hardening, validation, backup/fallback và regression test.
Có commit riêng.

### P1.1 — Farming Foundation
Commit:
`44e4e96 feat: implement p1 farming foundation`

Đã có:
- 6 farm tile.
- EMPTY / PLANTED / READY.
- R chọn/cycle seed.
- E plant/harvest.
- Validation tile, seed, level, inventory.
- Growth/yield/harvest item/EXP đọc từ `crops.json`.
- Không harvest trước READY.
- Inventory đầy không làm mất crop.
- Save/load crop ID, growth, READY.
- Giữ save schema hiện tại.

### Phase 4 — Animals
Commit:
`d28bb5ef70d3fd62b3a1c1f5b71e77adc1e102a3 feat: implement phase 4 animals`

Đã có:
- State machine chung cho chicken/cow/dairy cow.
- Chicken egg mỗi ngày.
- Chicken lifecycle 10 ngày → 10 chicken meat.
- Cow unlock level 2, purchase/economy, lifecycle/beef.
- Dairy cow milk production.
- EXP chỉ cộng khi sản phẩm vào inventory thành công.
- Inventory đầy giữ pending product.
- Housing capacity, purchase price, unlock đọc JSON.
- Save/load vị trí, tuổi, state, timer, pending products, collected state.
- Legacy save migration.
- Không tự sinh chicken cho zero-animal save.

Known limitation:
- Cow data nền đã dùng giá trị data-driven vì Master Plan local chưa định nghĩa đầy đủ; có thể balance lại trong JSON.
- Housing hiện dùng building level 1; upgrade coop/cow barn sẽ nối ở phase upgrade.

### Phase 5 — Aquaculture
Commit:
`e3f899cc0d0898a9726d760705240b2cd4ffcfbf feat: implement phase 5 aquaculture`

Đã có:
- State machine empty → growing → ready.
- Container fish/squid/octopus trong ONE WORLD.
- E interaction.
- Growth/yield/EXP/item/unlock từ `aquaculture.json`.
- Inventory đầy giữ pending product.
- Chống duplicate harvest.
- Save/load đầy đủ.
- Legacy v1 compatibility.
- Validation sâu.
- Không yêu cầu feed vì dataset hiện tại chưa định nghĩa input.

Known limitation:
- Shop/purchase UI và nâng cấp số khu aquaculture thuộc phase economy/UI sau.

### Phase 6 — Inventory + Economy
Commit:
`74afcc161e98694689a7c6d0e68ca6fb677372b0 feat: implement phase 6 inventory economy`

Đã có:
- Inventory stacking/capacity.
- Add/remove an toàn.
- Purchase seed/item/animal qua gameplay API.
- Sell crop, egg, milk, meat, seafood theo `items.json`.
- Wallet transaction/overflow protection.
- Atomic rollback.
- Warehouse upgrade theo `progression.json`.
- Save/load wallet, inventory, warehouse level.
- Legacy v1 compatibility.
- Không tạo manager/autoload mới.

Known limitation:
- Shop UI chưa làm; thuộc UI phase.
- Không tạo business funds riêng vì architecture hiện chưa có khái niệm này.
- `starting_money` trong dữ liệu hiện hữu từng là null/0; không tự ý thay đổi nếu Master Plan chưa chốt.

### Phase 7 — Restaurant Core
Commit:
`224674ef43d0ad46033cb16478b5f9a1dfe011ed feat: implement phase 7 restaurant core`

Đã có:
- Restaurant nằm trực tiếp trong `main_world`.
- Unlock level 4 từ `progression.json`.
- E interaction.
- Marker entrance/customer queue/order counter/kitchen/serving.
- 3 table entity theo capacity restaurant level 1.
- Table states: available/reserved/occupied/needs_cleanup.
- Menu lọc từ `recipes.json` với validation ingredients/item IDs/giá.
- Revenue qua wallet hiện tại.
- Save/load restaurant level/table state/occupant.
- Legacy save migration.

Known limitation:
- Customer AI/order/cooking/serving lifecycle chưa làm ở Phase 7.
- Restaurant upgrade level 1 chưa làm.
- Recipe thiếu ingredients không tự bịa dữ liệu.

## Regression quality hiện tại

Các phase gần đây đều được Codex chạy:
- Godot 4.7.1 parse/static check.
- Phase-specific regression.
- P0.2 regression.
- P1.1 regression.
- Phase 4 regression.
- Phase 5 regression.
- Phase 6 regression.
- Phase 7 regression.
- Main-world smoke test.
- JSON parse.
- `git diff --check`.
- Clean-cache headless regression.
- Test artifacts/log/cache không được commit.

Phase 7 kết thúc với:
`main...origin/main [ahead 7]`
và working tree sạch.

---

# 2. NHIỆM VỤ TIẾP THEO

## PHASE 8 — CUSTOMER + ORDER

Không quay lại rebuild Phase 7.
Không nhảy sang Phase 9 trước khi Phase 8 hoàn thành và commit.

Phase 8 tập trung vào:
- Customer entity.
- Customer state machine.
- Customer spawn.
- Tìm và giữ table.
- Order foundation.
- Recipe/order validation.
- Patience/waiting timer.
- Timeout và customer leaving.
- Table release.
- Save/load customer/order state cần thiết.
- Tích hợp Restaurant Core hiện tại.

State machine theo Master Plan:
`ENTER → SEATED → ORDERING → WAITING_FOOD → EATING → LEAVING`

Không tự ý đưa cooking execution đầy đủ vào Phase 8 nếu Master Plan chia nó sang Phase 9.

Phase 9:
- Cooking.

Phase 10:
- Staff / NPC.

Phase 11:
- Upgrade + Level.

Phase 12:
- Achievement.

Phase 13:
- UI.

Phase 14:
- Animation + Assets.

Phase 15:
- Polish + Bug Fix.

---

# 3. QUY TẮC KHI AGENT TIẾP QUẢN

1. Đọc `AGENTS.md` nếu repository có.
2. Đọc Master Plan trong tài liệu này.
3. Kiểm tra `git status` và commit hiện tại trước khi sửa.
4. Không rebuild architecture.
5. Không tạo autoload/manager trùng.
6. `GameManager` chỉ giữ orchestration/global state.
7. Gameplay system nên tách thành script riêng khi cần.
8. Data-driven: ưu tiên JSON, không hard-code gameplay values nếu dữ liệu đã có.
9. Save/load phải được nối ngay khi thêm gameplay state.
10. Giữ tương thích save v1 nếu có thể.
11. Không commit `.godot/`, cache, log, override hoặc test artifacts.
12. Sau mỗi phase phải có regression test.
13. Khi phase PASS phải tạo commit riêng.
14. Không sửa các phase cũ chỉ để đổi style.
15. Nếu dữ liệu Master Plan chưa định nghĩa thì không tự bịa balance quan trọng; giữ architecture mở và ghi rõ limitation.
16. ONE WORLD architecture là bắt buộc.
17. Lowercase naming là quy ước bắt buộc.

---

# 4. ONE WORLD / CORE LOOP

LaHoue không phải nhiều màn hình gameplay tách biệt.

Cấu trúc:
`MAIN WORLD`
- HUB
- FARM
- RESTAURANT

Core loop:
`FARM → PRODUCE → COOK → RESTAURANT → MONEY/EXP → LEVEL → UPGRADES → FARM AGAIN`

Ngày:
- 240 giây.
- 4 phút/ngày.
- Backspace → `finish_day()`.
- Không finish day khi paused.
- Save → day + 1.

Save file:
`user://savegame.json`

---

# 5. UI / VISUAL DIRECTION

UI không phải ưu tiên đầu tiên trong gameplay phases.

Khi tới UI:
- HUD trước.
- Management panels sau.
- Inventory.
- Shop.
- Recipes.
- Restaurant/order.
- Upgrade.
- Staff.
- Achievements.
- Pause.
- Notifications.

Phong cách:
- 2.5D / isometric.
- Màu sáng.
- Farm nhiều chi tiết.
- Nhân vật nhỏ.
- Nhà cửa có chiều sâu.
- Camera chéo từ trên xuống.
- Không realistic 3D.
- Ưu tiên: đẹp → rõ → dễ tương tác → nhẹ.

Animation tối thiểu:
- Player idle/walk/interaction.
- Animal idle/walk/eat/product.
- Chicken walk/peck/idle.
- Cow walk/eat/idle.
- Fish swim.
- Restaurant NPC walk/sit/eat/leave.
- Crop stages: seed → sprout → growing → mature → harvest.

---

# 6. MVP DEMO

Nếu deadline thiếu, MVP cần:
- Player movement.
- Farm/plant/grow/harvest.
- EXP/level.
- Inventory.
- Sell/VNĐ.
- Chicken/egg.
- Cow/beef.
- Aquaculture.
- Squid/octopus.
- Restaurant unlock lv4.
- Menu/recipe.
- Customer order.
- Cooking.
- Serving.
- Customer timeout.
- Money.
- 240s day.
- Backspace skip day.
- Save/load.

Sau đó mới:
- Staff.
- Deep upgrades.
- Wagyu/import.
- Expanded achievements.
- Full animation.
- Beautiful assets.
- UI polish.

---

# 7. GIT HANDOFF

Trước khi code:
`git status`

Sau khi code:
- test.
- regression.
- `git diff --check`.
- kiểm tra artifacts.
- `git status`.

Mỗi phase một commit.

Phase 7 commit cuối:
`224674ef43d0ad46033cb16478b5f9a1dfe011ed`

---

# 8. PROMPT KHỞI ĐỘNG CHO GEMINI / ANTIGRAVITY

Copy đoạn này vào Agent:

> Đây là project LaHoue, một game farm-to-table Godot 4.7.1.  
> Hãy đọc tài liệu handover này và repository hiện tại trước khi làm gì.
>
> Phase 1–7 đã hoàn thành. Không rebuild.
>
> Commit cuối của Phase 7:
> `224674ef43d0ad46033cb16478b5f9a1dfe011ed`
>
> Tiếp theo là Phase 8 — Customer + Order.
>
> Hãy:
> 1. kiểm tra git status;
> 2. đọc architecture hiện tại;
> 3. đọc restaurant.gd / restaurant_table.gd;
> 4. đọc GameManager, InventoryManager, SaveManager, DataManager;
> 5. đọc recipes.json, items.json, progression.json;
> 6. triển khai đúng Phase 8 theo Master Plan;
> 7. không làm Phase 9 Cooking execution;
> 8. không tạo manager/autoload trùng;
> 9. giữ lowercase naming;
> 10. giữ ONE WORLD;
> 11. nối save/load;
> 12. tạo regression test;
> 13. chạy toàn bộ regression liên quan;
> 14. chỉ commit khi test PASS và working tree sạch.
>
> Nếu dữ liệu chưa đủ, không tự bịa balance quan trọng. Ghi rõ limitation.
>
> Khi hoàn thành, báo files created/modified, tests, commit hash và known limitations.

---

# 9. MASTER PLAN GỐC

Dưới đây là nội dung Master Plan gốc đã được lưu trong context dự án. Không tự ý thay thế bằng một roadmap khác.

PLAN TỔNG THỂ GAME LAHOUE

Tên game: LaHoue
Slogan: On ne fait pas d'omelette sans casser des œufs
Engine: Godot 4.x
Phong cách: 2.5D / isometric, mô phỏng nông trại + nhà hàng + quản lý kinh doanh.
Đơn vị tiền: VNĐ.
Nguyên tắc code: tên file, biến, hàm, node và identifier viết thường, tránh lỗi chính tả và dễ quản lý.

1. Ý TƯỞNG CỐT LÕI

LaHoue là game farm-to-table.

Người chơi bắt đầu với một khu đất nhỏ, tự trồng trọt, chăn nuôi và khai thác thủy sản. Những sản phẩm thu được có thể:

thu hoạch → lưu kho → bán lấy tiền

hoặc:

thu hoạch → chế biến → phục vụ nhà hàng → kiếm nhiều tiền hơn

Ban đầu người chơi chưa có nhà hàng, chủ yếu kiếm tiền bằng nông sản, trứng, thịt, thủy sản...

Khi đạt Level 4, nhà hàng được mở khóa và gameplay chuyển sang giai đoạn quản lý nhà hàng.

2. BỐ CỤC THẾ GIỚI

Không làm 3 game/screen tách biệt.

Ta dùng một gameplay world thống nhất, gồm 3 khu vực chính:

                    LAHOUE
                       │
              ┌────────┴────────┐
              │   MAIN WORLD    │
              └────────┬────────┘
                       │
       ┌───────────────┼────────────────┐
       │               │                │
       ▼               ▼                ▼
     HUB             FARM          RESTAURANT
   sảnh chính       nông trại        nhà hàng
Khu 1 — HUB

Là khu trung tâm.

Có:

nhân vật người chơi
đường đi
kho
xe tải
khu mua bán
khu nâng cấp
các công trình chính
lối vào farm
lối vào restaurant
các NPC dịch vụ

Đây là nơi người chơi quản lý toàn bộ hoạt động.

3. KHU FARM

Farm là nguồn nguyên liệu chính.

Gồm:

Trồng trọt

Các hạt giống:

lúa
lúa mì
ngô
cà chua
bắp cải
trà
cà phê
các loại cây mở khóa về sau

Cây trồng có:

giá hạt giống
thời gian sinh trưởng
sản lượng
giá bán
EXP
level mở khóa
Thời gian

Không làm cây sinh trưởng quá lâu.

Ví dụ đã chốt:

lúa       ≈ 30 giây
lúa mì    ≈ 30 giây

Các cây khác sẽ được cân bằng tương tự, tránh gameplay quá chậm.

4. CHĂN NUÔI

Có nhiều nhóm gia súc/gia cầm.

Gà

Gà:

gà
 ↓
đẻ trứng
 ↓
thu hoạch trứng

Ngoài ra gà có vòng đời:

10 ngày

Sau vòng đời thu được:

10 item thịt gà

Thịt gà dùng để làm:

cơm gà — 79.000 VNĐ

Đây là một trong những nguyên liệu quan trọng của restaurant.

Bò ta

Bò ta:

bò ta
 ↓
thịt bò

Thịt bò:

bán trực tiếp
dùng chế biến món ăn

Bò cũng có thể bán để lấy tiền.

Bò sữa

Bò sữa:

bò sữa
 ↓
sữa bò

Sữa bò:

bán
dùng làm nguyên liệu đồ uống/món ăn sau này.
5. THỦY SẢN

Có khu vực nuôi/khai thác thủy sản.

Mục tiêu:

nuôi thủy sản
      ↓
thu hoạch
      ↓
item thủy sản
      ↓
bán
hoặc
chế biến

Các loại quan trọng phải có:

cá
mực
bạch tuộc
các loại hải sản khác

Mực và bạch tuộc là bắt buộc trong game, không được bỏ.

6. KHO

Kho là hệ thống quan trọng.

Kho có:

sức chứa
item
số lượng
nâng cấp capacity

Ví dụ:

kho lv1
 ↓
kho lv2
 ↓
kho lv3
...

Người chơi phải cân nhắc:

bán ngay hay giữ nguyên liệu để chế biến.

7. GAME ECONOMY

Tiền sử dụng hoàn toàn bằng:

VNĐ

Các hoạt động kiếm tiền:

nông sản
trứng
thịt gà
thịt bò
sữa bò
thủy sản
      ↓
    bán
      ↓
    VNĐ

Hoặc:

nguyên liệu
 ↓
chế biến
 ↓
nhà hàng
 ↓
bán món
 ↓
VNĐ

Nhà hàng sẽ có lợi nhuận cao hơn nhưng yêu cầu quản lý phức tạp hơn.

8. LEVEL / EXP

EXP đến từ hoạt động thực tế.

Ví dụ:

thu hoạch cây
thu hoạch trứng
nhận item cá
thu hoạch thủy sản
bán sản phẩm
chế biến
phục vụ khách
các hoạt động nhà hàng

Level mở khóa:

hạt giống
động vật
khu vực
kho
thiết bị
công thức
nhà hàng
nhân viên
nguyên liệu cao cấp
9. MỐC EXP ĐÃ CHỐT

Các mốc item/tiến trình đã đưa ra:

lv1  = 100
lv2  = 150
lv3  = 250
lv4  = 300
lv5  = 350
lv6  = 400
...
lv10 = 1000 item

Phần này nên để trong:

data/progression.json

thay vì hard-code trong GDScript.

10. NHÀ HÀNG

Restaurant mở ở Level 4.

Trước Level 4:

farm
 ↓
thu hoạch
 ↓
bán nguyên liệu
 ↓
tích tiền
 ↓
tăng EXP
 ↓
level up

Level 4:

RESTUARANT UNLOCK

Sau đó gameplay mở rộng:

farm
 ↓
nguyên liệu
 ↓
chế biến
 ↓
restaurant
 ↓
khách gọi món
 ↓
phục vụ
 ↓
tiền + exp + reputation
11. HỆ THỐNG KHÁCH HÀNG

Khách vào nhà hàng.

Khách có trạng thái.

Ví dụ:

ENTER
 ↓
SEATED
 ↓
ORDERING
 ↓
WAITING_FOOD
 ↓
EATING
 ↓
LEAVING

Khi khách gọi món, món được ghi vào trạng thái/order của khách.

Người chơi bấm chi tiết bàn:

BÀN 03
Khách:
- Cơm gà x1
- Nước...

Sau đó người chơi lấy nguyên liệu và chế biến.

12. KHÁCH KHÔNG CHỜ VÔ HẠN

Đây là gameplay quan trọng.

Khách có thời gian chờ.

Ví dụ:

ORDER
 ↓
waiting timer
 ↓
chờ quá lâu
 ↓
khách bỏ đi
 ↓
mất doanh thu
 ↓
ảnh hưởng reputation

Vì vậy người chơi phải cân bằng:

số bàn
số món
nguyên liệu
tốc độ nấu
nhân viên
13. NHÂN VIÊN NPC

Ban đầu:

người chơi tự làm phần lớn công việc.

Khi có đủ tiền và level:

Hire Employee

Nhân viên có thể phụ trách:

phục vụ
nhận order
mang món
các công việc restaurant
về sau có thể mở rộng sang farm

Lương nhân viên đã thống nhất:

lương tăng gấp đôi theo cấp/bậc đề xuất, nhưng khi kinh tế đã đủ mạnh thì các khoản lương nhỏ không phải vấn đề.

14. MENU / RECIPE

Demo phải có nhiều món, không chỉ 2–3 món.

Công thức nằm trong:

data/recipes.json

Ví dụ:

Cơm tỏi trứng

Nguyên liệu:

lúa
+
trứng

Không cần tỏi.

Giá trị nguyên liệu nhỏ không cần thiết sẽ bỏ để gameplay sạch.

Cơm gà
lúa
+
thịt gà

Giá:

79.000 VNĐ

Mì xào bò
lúa mì
+
thịt bò
Mì xào hải sản
lúa mì
+
hải sản

Có thể sử dụng:

cá
mực
bạch tuộc
hải sản khác
15. ĐỒ UỐNG

Nhà hàng có bán đồ uống.

Do đó farm có:

hạt trà
hạt cà phê

Kết hợp với:

sữa bò

để mở rộng hệ thống đồ uống.

16. NGUYÊN LIỆU CAO CẤP

Khi level đủ cao và kinh tế đủ mạnh:

IMPORT

Người chơi có thể nhập nguyên liệu nước ngoài.

Ví dụ:

Wagyu

Sau đó mở:

nguyên liệu premium
 ↓
recipe premium
 ↓
món cao cấp
 ↓
giá bán cao

Đây là hệ thống progression cuối game.

17. NÂNG CẤP

Người chơi có thể dùng tiền nâng cấp:

Kho
lv1
lv2
lv3
...
Chuồng trại

Tăng:

số lượng vật nuôi
khả năng nuôi
hiệu suất
Farm

Mở thêm:

đất
ô trồng
khu sản xuất
Thiết bị

Có thể nâng cấp:

tốc độ chế biến
sức chứa
thiết bị restaurant
các máy hỗ trợ sản xuất
Nhà hàng

Mở rộng:

số bàn
diện tích
bếp
thiết bị
khả năng phục vụ
18. GAME LOOP

Đây là GameLoop cốt lõi của LaHoue:

                    BẮT ĐẦU NGÀY
                         │
                         ▼
                  QUẢN LÝ FARM
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       TRỒNG CÂY      NUÔI GIA SÚC   THỦY SẢN
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                    THU HOẠCH
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
           BÁN ITEM             GIỮ ITEM
              │                     │
              ▼                     ▼
             VNĐ                 KHO
                                    │
                                    ▼
                            RESTAURANT LV4+
                                    │
                                    ▼
                              KHÁCH GỌI MÓN
                                    │
                                    ▼
                                CHẾ BIẾN
                                    │
                                    ▼
                                PHỤC VỤ
                                    │
                              ┌─────┴─────┐
                              ▼           ▼
                            VNĐ         EXP
                              │           │
                              └─────┬─────┘
                                    ▼
                                  LEVEL
                                    │
                   ┌────────────────┼──────────────┐
                   ▼                ▼              ▼
                FARM UP          KHO UP       RESTAURANT UP
                   │                │              │
                   └────────────────┼──────────────┘
                                    ▼
                                NGÀY MỚI
19. MỘT NGÀY TRONG GAME

Đã chốt:

240 giây / ngày

Tức khoảng:

4 phút / ngày

Cấu trúc:

DAY
│
├── OPEN
│
├── GAMEPLAY
│
├── END OF DAY
│
└── NEXT DAY

Backspace là shortcut đặc biệt:

Backspace
    ↓
finish_day()
    ↓
end day
    ↓
xử lý hệ thống
    ↓
save
    ↓
day + 1

Không được finish_day khi game đang pause.

20. SAVE / LOAD

Khi thoát game:

tự động save.

Lưu:

day
day_timer
money
EXP
level
reputation
inventory
crop state
animal state
restaurant state
progression

File:

user://savegame.json
21. ACHIEVEMENT

Game có hệ thống thành tựu.

Ví dụ nhóm thành tựu:

🌱 First Harvest
🐔 Chicken Farmer
🐄 Cattle Farmer
🐟 Fisher
🍳 First Recipe
🍗 First Chicken Rice
🏪 Restaurant Owner
⭐ Reputation
💰 Millionaire
🌾 Master Farmer

Achievement được mở rộng dần theo gameplay.

22. UI

Không làm UI quá phức tạp ngay từ đầu.

Gameplay HUD nên có:

┌────────────────────────────────────────────┐
│ DAY 1          ☀ TIME       ⭐ REP         │
│                                            │
│              GAME WORLD                    │
│                                            │
│                                            │
│                                            │
│                                            │
├────────────────────────────────────────────┤
│ 💰 100.000 VNĐ   LV 1   EXP ███░░          │
│ 🎒 12/100                                    │
└────────────────────────────────────────────┘

Các menu chính:

MENU
├── Inventory
├── Farm
├── Animals
├── Aquaculture
├── Recipes
├── Restaurant
├── Upgrade
├── Staff
├── Achievements
└── Save / Settings
23. PHONG CÁCH HÌNH ẢNH

Mục tiêu hình ảnh giống hướng các reference bạn đưa:

2.5D
isometric
màu sắc sáng
farm nhiều chi tiết
nhân vật nhỏ
nhà cửa có chiều sâu
cây trồng có nhiều stage
động vật có animation
restaurant nhìn được không gian
camera nhìn chéo từ trên xuống

Không làm kiểu 3D realistic.

Ưu tiên:

đẹp → rõ → dễ tương tác → nhẹ.

24. ANIMATION

Không để toàn bộ model đứng yên.

Tối thiểu:

Player
idle
walk up
walk down
walk left
walk right
interaction
Animal
idle
walk
eat
harvest/product animation
Chicken
walk
peck
idle
Cow
walk
eat
idle
Fish
swim
Restaurant NPC
walk
sit
eat
leave
Crop

Có stage:

seed
 ↓
sprout
 ↓
growing
 ↓
mature
 ↓
harvest
25. CẤU TRÚC GODOT ĐÃ CHỐT

Phase 1 hiện tại:

res://
├── autoload/
│   ├── data_manager.gd
│   ├── game_manager.gd
│   ├── inventory_manager.gd
│   └── save_manager.gd
│
├── data/
│   ├── items.json
│   ├── crops.json
│   ├── animals.json
│   ├── aquaculture.json
│   ├── recipes.json
│   └── progression.json
│
├── scenes/
│   └── world/
│       └── main_world.tscn
│
├── scripts/
│   └── world/
│       └── main_world.gd
│
└── phase1_notes.md

Không bung thành hàng chục module ngay từ đầu.

Chỉ tách module khi gameplay thực sự cần.

26. THỨ TỰ PHÁT TRIỂN

Vì deadline rất gấp, ưu tiên là:

PHASE 1
Foundation
        ↓
PHASE 2
Player + Movement + Interaction
        ↓
PHASE 3
Farm + Crop
        ↓
PHASE 4
Animals
        ↓
PHASE 5
Aquaculture
        ↓
PHASE 6
Inventory + Economy
        ↓
PHASE 7
Restaurant
        ↓
PHASE 8
Customer + Order
        ↓
PHASE 9
Cooking
        ↓
PHASE 10
Staff / NPC
        ↓
PHASE 11
Upgrade + Level
        ↓
PHASE 12
Achievement
        ↓
PHASE 13
UI
        ↓
PHASE 14
Animation + Assets
        ↓
PHASE 15
Polish + Bug Fix
Nhưng với deadline 2 ngày:

Không được đợi hoàn thiện UI/asset mới làm gameplay.

Ưu tiên:

GAME CHẠY
 ↓
GAMEPLAY LOOP
 ↓
DATA
 ↓
UI
 ↓
ASSET
 ↓
ANIMATION
 ↓
POLISH
27. MVP CẦN CÓ ĐỂ DEMO

Nếu thời gian không đủ, bản demo tối thiểu phải chạy được:

✅ Player đi lại
✅ Farm
✅ Trồng cây
✅ Cây lớn
✅ Thu hoạch
✅ EXP
✅ Level
✅ Inventory
✅ Bán item
✅ VNĐ
✅ Gà
✅ Trứng
✅ Bò
✅ Thịt bò
✅ Thủy sản
✅ Mực
✅ Bạch tuộc
✅ Restaurant unlock lv4
✅ Menu
✅ Recipe
✅ Customer order
✅ Cooking
✅ Serving
✅ Customer timeout
✅ Money
✅ Day 240s
✅ Backspace skip day
✅ Save/Load

Sau đó mới ưu tiên:

NPC staff
upgrade sâu
import wagyu
achievement mở rộng
animation đầy đủ
asset đẹp
UI polish
28. NGUYÊN TẮC QUAN TRỌNG NHẤT

Không xây game theo kiểu làm từng màn hình riêng.

LaHoue phải là:

              ONE WORLD
                  │
        ┌─────────┼─────────┐
        │         │         │
       HUB       FARM    RESTAURANT
        │         │         │
        └─────────┼─────────┘
                  │
             ONE GAME LOOP
                  │
       FARM → PRODUCE → COOK
                  ↓
             RESTAURANT
                  ↓
              MONEY/EXP
                  ↓
               LEVEL
                  ↓
              UPGRADES
                  ↓
              FARM AGAIN

Đây chính là xương sống của LaHoue.