/**
 * Quan hệ NPC — kiểu dữ liệu của data/systems/relationships.json và phần lưu s.rel.
 * Mã chạy: scripts/systems/relationships.gd (GDScript đọc đúng cấu trúc này).
 *
 * Điểm thân thiết 0..100 vẫn nằm ở s.rep[npc] như các chương cũ; file này thêm:
 *   - bậc quan hệ (tier) theo điểm, đặt riêng được cho từng người;
 *   - mốc (milestone): qua điểm X lần đầu thì mở tin nhắn, đẩy sự kiện truyện, bật trạng thái;
 *   - trạng thái quan hệ (status) như "Cặp đôi": gắn với một trạng thái sinh tồn (survival.json) để có buff;
 *   - tin nhắn trên điện thoại (app Tin nhắn): mở theo điều kiện, có lựa chọn trả lời;
 *   - phai nhạt: lâu không gặp thì điểm tụt dần.
 */

/** Khóa điều kiện dùng chung với GameLogic.check(): "rep.X", "flag.X", "stat.X", "day_min", "has_cond"… */
export type Conditions = Record<string, unknown>;
/** Khóa hiệu ứng dùng chung với GameLogic.apply_effects(): "rep.X", "need.mood", "flag.X", "cond.X", "queue"… */
export type Effects = Record<string, unknown>;

export type NpcId = string; // "HAN", "LINH", "BA_TU"…

export interface Tier {
  /** Điểm tối thiểu để vào bậc này (bậc cao nhất thỏa điều kiện thắng). */
  min: number;
  name: string; // "Quen", "Thân thiết", "Tri kỷ"…
  /** Màu chữ trên giao diện, hex không có #. */
  color?: string;
}

export interface Milestone {
  id: string;
  /** Mở khi s.rep[npc] >= at và thỏa when. Mỗi mốc chỉ chạy một lần (s.rel.fired). */
  at: number;
  when?: Conditions;
  /** Tin nhắn được mở khóa (id trong messages của người này). */
  unlockMessages?: string[];
  /** Sự kiện truyện đẩy vào hàng chờ (id trong events*.json), hiện như cảnh có lựa chọn. */
  event?: string;
  /** Hiệu ứng thêm khi đạt mốc (nhật ký, cờ…). */
  effects?: Effects;
}

export interface RelationStatus {
  name: string; // "Cặp đôi"
  /** Trạng thái sinh tồn bật kèm (survival.json conditions) để có buff: regen.mood, fatigue.rate… */
  condition?: string;
  /** Điểm dưới mức này thì trạng thái tự mất (chia tay, nguội lạnh). */
  breakBelow?: number;
  /** Sự kiện chạy khi mất trạng thái. */
  breakEvent?: string;
  desc?: string;
}

export interface ReplyOption {
  label: string;
  effects?: Effects;
  /** Câu trả lời của người kia hiện ngay sau. */
  answer?: string;
  require?: Conditions;
}

export interface Message {
  id: string;
  /** Điều kiện để tin này tới máy (ngoài việc được mốc mở khóa). Có unlockOnly thì chỉ mốc mới mở được. */
  when?: Conditions;
  unlockOnly?: boolean;
  /** Không tới trước giờ này trong ngày (giờ thực trong game, 0..24). */
  after?: number;
  /** Các dòng tin người kia gửi, theo thứ tự. */
  lines: string[];
  /** Không có replies thì chỉ cần đọc. */
  replies?: ReplyOption[];
}

export interface NpcRelation {
  /** Tên hiển thị; mặc định lấy từ story.reps. */
  name?: string;
  /** Điểm đầu ván nếu s.rep chưa có người này. */
  start?: number;
  /** Người này ở đâu để nói chuyện khi không có trong world.npcs_at (xe hàng rong: "vendor:hoa"). */
  anchor?: string;
  /** Tuyến tình cảm: mở bậc riêng và trạng thái Cặp đôi. */
  romance?: boolean;
  tiers?: Tier[];
  milestones?: Milestone[];
  statuses?: Record<string, RelationStatus>;
  messages?: Message[];
  /** Tương tác thêm ngoài tán gẫu (giúp việc, tặng quà): id việc trong cfg.actions. */
  actions?: string[];
}

export interface RelationshipsConfig {
  /** Bậc mặc định cho người không có tiers riêng. */
  tiers: Tier[];
  decay: {
    /** Không gặp (nói chuyện, nhắn tin, làm việc cùng) quá ngần này ngày thì bắt đầu tụt. */
    graceDays: number;
    /** Điểm tụt mỗi ngày sau thời gian ân hạn. */
    perDay: number;
    /** Không tụt xuống dưới mức này. */
    floor: number;
  };
  /** Trả lời tin nhắn tính như gặp mặt (dời mốc phai nhạt) và cộng điểm. */
  replyRep: number;
  npcs: Record<NpcId, NpcRelation>;
}

/* ------------------------------------------------------------ phần lưu trong save (s.rel) */

export interface InboxEntry {
  npc: NpcId;
  msg: string; // Message.id
  /** Giờ tuyệt đối lúc tới máy (GameClock.abs_hours). */
  at: number;
  read: boolean;
  /** Chỉ số lựa chọn đã trả lời, -1 nếu chưa. */
  replied: number;
}

export interface RelSave {
  /** Mốc đã chạy: "HAN:tim_hieu". */
  fired: string[];
  /** Trạng thái quan hệ đang có: {HAN: "cap_doi"}. */
  status: Record<NpcId, string>;
  /** Ngày gặp gần nhất, cho phần phai nhạt. */
  seen: Record<NpcId, number>;
  /** Tin đã mở khóa bởi mốc (chưa chắc đã tới máy nếu còn chờ giờ). */
  unlocked: string[];
  inbox: InboxEntry[];
}
