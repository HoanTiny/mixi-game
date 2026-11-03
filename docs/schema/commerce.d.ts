/**
 * Kinh tế buôn bán — kiểu dữ liệu của data/systems/commerce.json và phần lưu s.biz.
 * Mã chạy: scripts/systems/commerce.gd. Giao diện: thẻ việc ở chợ Long Biên, điểm bán; app Shippy trên điện thoại;
 * màn livestream scripts/ui/live_session.gd.
 *
 * Vòng chơi:
 *   Bán hàng rong:  xem giá sỉ hôm nay → nhập lô ở chợ Long Biên → mang theo (xe đẩy có sức chứa) hay để kho →
 *                   chọn điểm bán và khung giờ → bày bán N giờ (mỗi giờ tính khách qua, khách quan tâm, tỷ lệ chốt) →
 *                   nếu điểm không được phép bán thì có rủi ro trật tự đô thị thu hàng, phạt tiền.
 *   Livestream:     thuê kho (có thể lắp quạt hút ẩm) → nhập hàng vào kho → chọn kịch bản, người chốt đơn, đóng gói →
 *                   lên sóng (màn tương tác: tung deal, phát voucher đúng lúc, trả lời bình luận) → đơn chờ giao →
 *                   sau vài ngày đơn thành công (nhận tiền COD) hay bị hoàn (boom), ảnh hưởng uy tín shop.
 */

export type Conditions = Record<string, unknown>;
export type GoodId = string; // "hoa_hong", "ao_mua"…
export type Bin = "cart" | "kho";

export interface Good {
  name: string;
  unit: string; // "bông", "chiếc"…
  /** Giá nhập sỉ gốc một đơn vị (đồng), nhân hệ số thị trường hôm đó. */
  buyBase: number;
  /** Giá bán lẻ tham chiếu một đơn vị ("giá chợ"). */
  sellBase: number;
  /** Mỗi lô nhập ở chợ: số đơn vị. */
  lot: number;
  /** Biên độ dao động giá theo ngày (0.1 = ±10% mỗi ngày quanh xu hướng). */
  volatility: number;
  /** Héo, hỏng sau ngần này ngày (hoa). Không có thì không hỏng theo ngày. */
  perishDays?: number;
  /** Dễ mốc trong kho ẩm (quần áo, đồ chơi vải) nếu kho chưa có quạt hút ẩm. */
  mold?: boolean;
  /** Bán được qua kênh nào. */
  channels: Array<"street" | "live">;
  /** Hệ số cầu theo hoàn cảnh: rain (trời mưa), weekend (thứ Bảy, Chủ Nhật), evening (từ 17:00), morning (trước 10:00). */
  demand?: Partial<Record<"rain" | "dry" | "weekend" | "evening" | "morning", number>>;
  /** Mô tả ngắn hiện trong app. */
  desc?: string;
}

export interface Spot {
  /** id địa điểm trong thế giới (world.LOCATIONS). */
  location: string;
  name: string;
  /** Được phép bày bán không. false: có rủi ro trật tự đô thị. */
  legal: boolean;
  /** Phí chỗ (vé chợ) mỗi lần bày bán. */
  fee?: number;
  /** Khách qua mỗi giờ theo khung giờ: [từ giờ, tới giờ, số khách]. */
  traffic: Array<[number, number, number]>;
  /** Hệ số cầu riêng từng món ở điểm này (hoa ở hồ Gươm buổi tối…). */
  demand: Partial<Record<GoodId, number>>;
  /** Trật tự đô thị: xác suất mỗi giờ bị bắt gặp trong khung giờ đi tuần. */
  inspector?: { perHour: number; hours: [number, number] };
  desc?: string;
}

export interface MarketEvent {
  id: string;
  when: Conditions; // ví dụ {"rain_today": true}, {"weekday": [0, 6]}
  good: GoodId;
  /** Nhân vào hệ số giá nhập (buy) và cầu (demand) trong ngày. */
  buy?: number;
  demand?: number;
  text: string;
}

export interface PriceTier {
  name: string; // "Bán rẻ", "Giá chợ", "Hét giá"
  /** Nhân giá bán so với giá chợ hôm đó. */
  price: number;
  /** Nhân tỷ lệ chốt đơn. */
  close: number;
}

export interface VendingConfig {
  /** Sức chứa xe đẩy (đơn vị hàng), cộng thêm theo cấp Thể chất trên 1. */
  cartBase: number;
  cartPerStr: number;
  /** Tỷ lệ khách quan tâm chốt mua ở giá chợ, trước các hệ số. */
  baseClose: number;
  /** Cộng tỷ lệ chốt mỗi cấp Nhạy bén trên 1. */
  closePerPer: number;
  /** Tâm trạng dưới mức này thì chốt kém đi (closeLowMood). */
  lowMood: number;
  closeLowMood: number;
  /** Phần khách qua đường để ý tới gánh hàng (nhân với cầu của món). */
  interest: number;
  priceTiers: Record<string, PriceTier>;
  /** Bị trật tự đô thị bắt: mất phần hàng mang theo, nộp phạt, tụt Tâm trạng. Nhạy bén giảm xác suất mỗi cấp. */
  fine: { confiscate: number; money: number; mood: number; perPerLevel: number };
}

export interface WarehouseConfig {
  location: string;
  name: string;
  rentPerDay: number;
  /** Trả trước theo tuần khi thuê. */
  rentDays: number;
  capacity: number;
  ventCost: number;
  /** Phần hàng dễ mốc bị hỏng mỗi ngày mưa / ngày khô khi chưa có quạt hút ẩm. */
  moldRain: number;
  moldDry: number;
}

export interface LiveScript {
  name: string;
  /** Nhân tỷ lệ chốt, tỷ lệ hoàn và lượng người xem. */
  close: number;
  returns: number;
  viewers: number;
  /** Rủi ro nói hớ bị khóa kênh mỗi lần tung deal. */
  risk: number;
  desc: string;
}

export interface LiveConfig {
  unlock: Conditions;
  /** Nơi lên sóng được (phòng trọ, quán net). */
  locations: string[];
  hours: number;
  /** Màn tương tác dài bao nhiêu giây thật, chia thành beats nhịp. */
  seconds: number;
  beats: number;
  baseViewers: number;
  /** Người xem tăng theo uy tín shop: viewers × (0.4 + 1.2 × uyTin/100), uy tín 50 là ×1, 90 là ×1,48. */
  scripts: Record<string, LiveScript>;
  /** Phần người xem có ý mua mỗi nhịp, trước hệ số. */
  intent: number;
  baseClose: number;
  /** Voucher: giảm giá (phần trăm) đổi lấy tăng chốt; hiệu quả gấp đôi khi bấm lúc người xem đang đỉnh. */
  voucher: { discount: number; close: number; peakBonus: number };
  /** Deal chớp nhoáng: tăng chốt trong một nhịp, mỗi lần bấm cộng rủi ro khóa kênh của kịch bản. */
  flash: { close: number; cooldownBeats: number };
  /** Trả lời bình luận: tăng người xem nhịp sau. */
  reply: { viewers: number };
  staff: Record<"closer" | "packer", { name: string; wage: number; max: number; desc: string }>;
  /** Một người chốt đơn xử lý tối đa ngần này đơn mỗi nhịp; không thuê thì An tự chốt (closerSolo). */
  closerCap: number;
  closerSolo: number;
  /** Một người đóng gói đóng ngần này đơn mỗi ngày; An tự đóng packerSolo đơn. Quá thì đơn giao trễ. */
  packerCap: number;
  packerSolo: number;
  /** Phí sàn, phí giao mỗi đơn. */
  feeRate: number;
  shipFee: number;
  banDays: number;
}

export interface ReturnsConfig {
  /** Xác suất hoàn cơ bản, nhân kịch bản; cộng thêm nếu giao trễ; giảm theo uy tín. */
  base: number;
  late: number;
  repProtect: number;
  /** Đơn bị hoàn: mất phí giao hai chiều, hàng về kho (hàng dễ hỏng thì mất). */
  /** Số ngày từ lúc chốt tới lúc biết kết quả đơn. */
  days: number;
  /** Uy tín shop 0..100. */
  repStart: number;
  repPerReturn: number;
  repPerGood: number;
}

export interface CommerceConfig {
  goods: Record<GoodId, Good>;
  /** Chợ đầu mối nhập sỉ. */
  wholesale: { location: string; name: string };
  spots: Record<string, Spot>;
  market: { drift: number; clamp: [number, number]; events: MarketEvent[] };
  vending: VendingConfig;
  warehouse: WarehouseConfig;
  live: LiveConfig;
  returns: ReturnsConfig;
}

/* ------------------------------------------------------------ phần lưu trong save (s.biz) */

export interface Lot {
  good: GoodId;
  qty: number;
  /** Giá vốn một đơn vị. */
  cost: number;
  day: number;
  bin: Bin;
}

export interface MarketState {
  /** Hệ số giá nhập so với buyBase hôm nay. */
  buy: number;
  /** Xu hướng (cộng dồn qua ngày), để giá có lên có xuống thật chứ không nhảy loạn. */
  trend: number;
  /** Hệ số cầu hôm nay (sự kiện thị trường). */
  demand: number;
  news: string;
}

export interface Order {
  id: number;
  good: GoodId;
  qty: number;
  /** Tiền khách trả (sau voucher). */
  price: number;
  cost: number;
  /** Ngày biết kết quả. */
  due: number;
  late: boolean;
  /** Tỷ lệ hoàn đã chốt lúc bán (kịch bản, uy tín). */
  risk: number;
}

export interface BizSave {
  lots: Lot[];
  marketDay: number;
  market: Record<GoodId, MarketState>;
  tier: string; // khóa trong vending.priceTiers
  warehouse: { rented: boolean; paidTo: number; vent: boolean };
  staff: { closer: number; packer: number };
  /** Uy tín shop Shippy 0..100. */
  rep: number;
  orders: Order[];
  /** Đơn chốt hôm nay chưa đóng gói (để tính trễ). */
  packedToday: number;
  banUntil: number;
  stats: { streetSold: number; streetRevenue: number; liveOrders: number; returned: number; fined: number };
  /** Kết quả lần bán gần nhất, cho thẻ tóm tắt. */
  last: { kind: "street" | "live"; text: string } | null;
}
