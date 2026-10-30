> Cập nhật Phúc Tân: mở đầu mới có **46.000đ trong ví + 1.400.000đ quỹ cọc khóa**. Quỹ chỉ thanh toán phần cọc nhà; không mua đồ, trả trọ hay bù chi phí sinh hoạt. Vì đã có sẵn phần lớn tiền cọc, mốc 20–30 ngày bên dưới chỉ còn là benchmark cũ bắt đầu với 180k và không có quỹ. Không áp mốc đó cho mở đầu mới. Trả trọ thủ công 60k sẽ bỏ khoản trọ tự thu của đúng đêm đó; nợ cũ vẫn phải trả. Save ngày 1 chưa tách quỹ có tiền mặt ≥1,4 triệu được chuyển 1,4 triệu sang quỹ một lần, giữ nguyên tổng tài sản. Save khác giữ nguyên tiền.

# Economy, survival and relationships

## Data and saved state

- `data/systems/economy.json` sets new full-game cash to 180,000đ. Loading an
  existing save never replaces the player's cash. Slice presets and later
  chapters keep their existing budgets.
- Chapter 1 charges **60,000đ room rent per night**, itemized separately from
  **60,000đ family upkeep** (household supplies, medicine and utilities; excludes
  An's purchased meals). This replaces the old undifferentiated 120,000đ expense.
  Sleeping elsewhere replaces that night's room charge. Unpaid rent persists as
  `s.economy.rentArrears` and is collected on later nights; repeated callbacks
  cannot charge the same night twice.
- Repeatable work has a base ceiling of 28,000đ/hour before performance and
  career modifiers. The eight-hour warehouse shift, which includes a meal, pays
  200,000đ at full quota instead of 300,000đ. Grades still matter; the cap does
  not flatten Perfect/Good/Fail into the same result. Existing money rounding
  is in 10,000đ steps.
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

## Deterministic budget test

Run `tests/economy_relationships.gd` with Godot 4.7.2 headless. This test uses
the real `do_action`, zone-travel, need-decay, `finish_day` and money APIs. It
disables authored events/contracts/one-off rewards only, explicitly isolating
the repeatable work budget. No daily stat or money resets occur during the
simulation. Initial needs are standardized to 80 and fatigue to zero to avoid
the opening conversation affecting the comparison.

Daily route: 25 minutes to the market, breakfast or packed lunch, laundry soap
when the last bar is used up (15,000đ for three washes), eight-hour warehouse
shift at full quota, 25 minutes home, shared family meal, two hours rest, bath
and laundry, then sleep around 18:41 (19:05 with lunch preparation). The cold
tap bath can give An a cold, so on evenings when mood is already below 50 the
route pays 25,000đ for the public hot bath instead. This leaves about three
hours of the 16-hour day for story errands; skipping rest or meals can reduce
performance and income.

| Strategy | Daily net after baseline expenses | First deposit-ready evening |
| --- | --- | --- |
| Buy 15,000đ breakfast every day | 50,000–65,000đ (soap, occasional hot bath) | Day 28: 1,825,000đ |
| Unlock and use family lunch after seven shared meals | as above through day 7, then up to 80,000đ | Day 24 |

These are representative successful schedules, not a hard time gate. Perfect
results, additional shifts, contracts, risk-taking and easy-mode starting
money can shorten the route; failed shifts and entertainment spending extend
it. Tests additionally cover rent arrears, alternate lodging, one-time
settlement, relationship reload, threshold slicing and lunch consumption.
