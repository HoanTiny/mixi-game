> Cập nhật Phúc Tân: mở đầu mới có **46.000đ trong ví + 1.400.000đ quỹ cọc khóa**. Quỹ chỉ thanh toán phần cọc nhà; không mua đồ, trả trọ hay bù chi phí sinh hoạt. Vì đã có sẵn phần lớn tiền cọc, mốc 20–30 ngày bên dưới chỉ còn là benchmark cũ bắt đầu với 180k và không có quỹ. Không áp mốc đó cho mở đầu mới. Trả trọ thủ công 60k sẽ bỏ khoản trọ tự thu của đúng đêm đó; hệ hardship hiện ghi số đêm nợ; cơ chế thu nợ tiền của Economy là nhánh riêng, chưa thống nhất. Save ngày 1 chưa tách quỹ có tiền mặt ≥1,4 triệu được chuyển 1,4 triệu sang quỹ một lần, giữ nguyên tổng tài sản. Save khác giữ nguyên tiền.

# Economy, survival and relationships

## Data and saved state

- `data/systems/economy.json` sets new full-game cash to 46,000đ plus a locked 1,400,000đ deposit fund. Loading an
  existing save never replaces the player's cash. Slice presets and later
  chapters keep their existing budgets.
- Shipped chapter 1 uses hardship: 60,000đ nightly rent and zero automatic family upkeep. These values are loaded from economy.json. Meals are separate actions. Hardship records unpaid nights; the legacy Economy arrears API is still tested independently and is not the live chapter-one collection path.
- With hardship active, ordinary authored job pay is retained (warehouse base 300,000đ); beer service retains the hourly cap. The 28,000đ/hour and 200,000đ warehouse cap apply to the legacy economy path. Work performance is sampled before action time passes.
- Repeatable 3D repair orders use the same economy data when quoted: fan
  90,000đ and kettle 110,000đ before the existing 10% independent-trade and
  20,000đ loyal-customer bonuses. Buying the part from the shop costs 50,000đ
  or 45,000đ respectively, leaving 40,000đ/65,000đ before bonuses. These orders
  previously bypassed the action wage cap with 230,000đ/260,000đ direct payouts.
  Offer text and acceptance now share one quote function. Existing accepted
  orders, the opening fan quest and day2–3 narrative orders retain their saved
  agreed payments; no retroactive pay cut occurs on loading.
- **1,800,000đ is the Ngọc Thụy deposit target**, not the complete lease cost:
  the existing story still requires 4,200,000đ total and tracks the remaining
  obligation separately. Narrative contracts, receivables, gifts and easy mode
  are intentional alternate routes; the benchmark below does not guarantee a
  minimum completion day for every strategy.

## Hourly survival

`survival.decayPerHour` contains signed rates: stamina −0.75, hunger −6,
hygiene −2, mood −1.2 points/hour. Stamina remains `100 - fatigue`; there is no
second competing stamina field. Clothing cleanliness keeps the existing rate.
Difficulty and timed-condition modifiers continue to apply.

When hunger **or** hygiene is below 30, negative mood decay doubles. Both low
needs together still apply **2×**, never 4×. Integration splits precisely at
30/0 crossings and timed-buff expiration; two healthy hours followed by one
hungry hour only penalize the hungry hour. Starvation fatigue also starts only
when hunger actually reaches zero. Action time is consumed before meal, bath
or rest recovery, so a meal at the end of a shift cannot erase earlier hunger.
Zero-time UI refreshes never decay stats. Overnight recovery remains the
existing explicit sleep rule, not daytime hourly decay applied a second time.

## NPC relationships and hidden lunch choice

The existing `s.rep` remains the canonical affection score for story checks.
`s.relationships.npcs` stores a mirrored affection score plus independent
0–100 trust for Bà Thoa (`BA_TU`), Linh and Cô Duyên. Existing saves receive
initial trust without overwriting their reputation.

Eating `com_voi_ba` still raises affection by its existing +3 and adds +3 trust
once per distinct day. The hidden choice **Nhờ bà nấu cơm hộp mang đi làm**
unlocks at affection 75, trust 70 and seven shared-meal days. A 15-minute
preparation creates one dated inventory item per day. An can eat it for free
in Tạ Hiện or the market/worksite zone: 15 minutes, +55 hunger, consumes the
item. It cannot be eaten twice, stacked across days or used while at home;
unused food expires next morning. Linh/Duyên trust gains from supportive
actions are also bounded to once per NPC per day.

## Budget regression

`tests/economy_relationships.gd` retains focused survival/relationship/legacy-arrears checks, then enables the shipped hardship policy for its route simulation. Initial wallet is 46,000đ and housing fund 1,400,000đ. The route pays rent before resting and uses paid laundry, rather than attempting laundry without soap.

A full-quota warehouse route with meals, rest, bathing and paid laundry reaches the 1.8m deposit on day 2 (456,000đ cash + 1.4m fund), before the family-lunch unlock. This is not the full 4.2m housing cost and not proof of balanced 30-day play. The old 22/25-day zero-fund benchmark is retired. The test checks feasibility before day 26, not a minimum grind duration. A three-career/performance/old-wage scenario matrix remains outstanding.

See WEEK_ONE_IMPLEMENTATION.md for the new authored day 5–6 contracts and save recovery checks.
