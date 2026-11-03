extends RefCounted
## Short, original Hanoi observations. They frame an encounter without changing
## story flags, granting rewards or pretending a background animation is a quest.
const SCENES := {
	"xom_bo_me": ["Tiếng chậu nhôm chạm nền sân. Bà Thoa chừa lối giữa dây phơi cho người đi làm sớm.", "Sân trọ còn mùi xà phòng. Mỗi phòng hé một cánh cửa, tiếng người gọi nhau vọng qua hẻm.", "Đèn các phòng bật dần. Có người đợi một bữa cơm, có người vẫn chưa tan ca."],
	"com_hanh": ["Chị Hạnh xếp bát bên nồi cơm vừa cắm. Hàng ghế sát tường còn trống, một ngày làm việc sắp bắt đầu.", "Hơi nóng đọng trên tủ thức ăn. Khách ăn xong kéo ghế vào để người sau còn chỗ ngồi.", "Mấy người tan ca ăn chậm ở bàn trong. Chị Hạnh nhìn nồi cơm rồi hỏi ai còn muốn thêm."],
	"tiem_sau": ["Chú Sơn kéo cửa xưởng, đặt bộ đồ nghề cạnh chiếc xe chờ sửa từ tối qua.", "Mùi dầu máy bám quanh bàn sửa. Một con ốc nhỏ cũng phải có chỗ đặt, kẻo tìm cả buổi không ra.", "Ánh đèn hắt xuống bàn dụng cụ. Chú Sơn gom những món chưa xong để sáng mai làm tiếp."],
	"cho_cau_nho": ["Xe hàng về từ lúc trời tối. Người cân rau, người buộc sọt, chừa một lối hẹp cho khách vào chợ.", "Bạt sạp che nắng, thùng hàng chất sát vách. Cô Thắm vừa cân đồng nát vừa nghe chuyện người qua lại.", "Sạp lẻ bắt đầu thu dọn. Ở phía bãi xe, một ca hàng khác lại sắp tới."],
	"ben_xe_6": ["Người đi ca sớm đứng dưới mái chờ, tay giữ túi đồ ăn và mắt nhìn về đầu đường.", "Bóng mái che lùi dần trên vỉa hè. Người mới đến hỏi nhau chuyến xe tiếp theo.", "Xe về thành phố mang theo những người mệt sau một ngày làm. Ghế chờ lại đổi người."],
	"bai_boc_vac": ["Những sọt cuối cùng được chuyển khỏi xe. Người hết ca ngồi uống nước bên mép bãi.", "Bạt được buộc lại, xe trống chờ chuyến hàng mới. Anh cai ngó từng người tới hỏi việc.", "Tiếng gọi nhau nổi lên giữa đèn xe. Bốc hàng ban đêm cần sức, nhưng cũng cần giữ nhịp với người cùng khiêng."],
	"xe_tho": ["Chú cho thuê xe kiểm dây buộc trước khi giao xe. Một chuyến hàng bắt đầu bằng những việc nhỏ như thế.", "Các xe trống tựa sát mái che. Bánh xe còn vệt bụi của chuyến hàng vừa trả.", "Xe lần lượt được đưa về. Chú chủ đếm lại dây và ghi những chuyến còn chưa thanh toán."],
	"hem_dua": ["Ánh sáng lọt qua đầu ngõ hẹp. Tiếng người chuẩn bị đi làm vọng xuống từ căn gác.", "Một chậu cây nép bên cửa. Muốn biết căn gác có hợp để ở, phải hỏi cả chuyện nóng, ồn và chỗ phơi đồ.", "Đèn quán ngoài ngõ còn sáng. Người thuê phòng khép cửa để bớt tiếng phố."],
	"cau_tre": ["Gió sông luồn qua hiên. Từ đây sang chỗ làm còn một quãng đường qua cầu.", "Hiên nhà thoáng, vài món đồ phơi đung đưa. Chú chủ nhà chờ người tới xem phòng.", "Bên kia sông đã lên đèn. Căn phòng yên hơn phố, đổi lại là chuyến về dài hơn."],
	"nha_di_nam": ["Dì Nga dọn chỗ bên cửa cho khách ngồi. Ở nhờ cũng có những điều cần nói rõ từ đầu.", "Tiếng bát đũa vọng từ phía sau nhà. Đồ mang theo phải xếp gọn để còn lối đi chung.", "Dì Nga để một ngọn đèn ở cửa. Bữa cơm nhà kéo câu chuyện chậm lại."],
	"nha_tro_giuong": ["Có người vừa về sau ca đêm, người khác đang buộc lại túi để ra phố. Cả phòng nói nhỏ.", "Bà chủ trọ phơi chăn trước lúc nhận khách mới. Chỗ ngủ rẻ cần đổi bằng không gian dùng chung.", "Dép xếp thành hàng ngoài cửa. Mỗi giường là một người lạ cần nghỉ cho ngày mai."],
	"quan_net": ["Vài khách ca đêm vẫn chưa đứng dậy. Quạt thổi qua dãy máy, bên quầy có người hỏi tin tuyển dụng.", "Ánh màn hình hắt qua cửa. Có người chơi, có người tranh thủ tìm một chỗ làm.", "Phố bớt tiếng xe nhưng quán vẫn sáng. Một giờ giải trí cũng là một khoản phải tính."],
	"cam_do": ["Cửa sắt vừa mở. Món đồ mang tới được đặt lên quầy, rồi câu chuyện mới bắt đầu.", "Chủ tiệm kiểm từng vết xước trước khi báo giá. Tiền nhận hôm nay đi cùng một hạn chuộc.", "Đèn quầy còn sáng sau lớp cửa sắt. Người tới cửa thường nhìn món đồ trong tay thêm một lần."],
	"ve_so": ["Những xấp vé mới nằm ngay ngắn dưới tấm kính. Tiếng mời mua chen vào nhịp người đi chợ.", "Người bán giữ một góc vé khỏi gió. Ai cũng có việc phải làm trước giờ mở thưởng.", "Có người dò lại con số, có người gấp vé cất đi. Phố vẫn tiếp tục một ngày của nó."],
	"ho_guom": ["Người tập sớm nhường nhau khoảng sân dưới cây. Cụ Thiện xếp những quân cờ lên bàn đá.", "Mặt hồ sáng sau tán lá. Một chỗ ngồi yên giúp nghe rõ tiếng phố hơn.", "Người đi dạo chậm lại bên hồ. Có những câu chuyện chỉ được kể khi không còn vội."],
	"shop_ao": ["Chị Vy mở kiện hàng, treo vài chiếc áo ra phía cửa để nhìn màu dưới ánh sáng trời.", "Giá áo sát tường, chừa khoảng cho khách thử. Một món đồ vừa người có khi cần tìm lâu hơn món rẻ.", "Chị Vy gấp những chiếc áo khách đã xem. Đèn quầy làm dãy vải cũ dịu màu hơn."],
	"bi_a": ["Quán mở cửa cho thoáng, bàn được phủi lại. Anh Dũng kiểm đầu cơ trước lúc có khách.", "Ánh đèn tập trung trên mặt bàn xanh. Tiếng bi chạm nhau tách khỏi tiếng xe ngoài cửa.", "Khách đứng chờ lượt bên tường. Một ván vui là đủ, ngày mai vẫn còn việc phải làm."],
	"tiem_toc": ["Ghế được lau sạch, khăn xếp cạnh gương. Anh thợ ngó ra phố đợi khách đầu ngày.", "Ánh sáng từ cửa rọi lên tấm gương. Một mái tóc gọn làm người ta thấy mình sẵn sàng hơn.", "Anh thợ quét tóc dưới chân ghế, nhận thêm người khách cuối trước giờ đóng cửa."],
	"ben_can": ["Những chiếc ghế được chồng sát tường. Dãy quán yên hơn nhiều so với lúc tối.", "Người trong quán chuẩn bị bàn, kiểm lại ổ điện và lối đi chung trước giờ đông khách.", "Đèn quán nối thành một dải ấm. Người trò chuyện sát bàn, người phục vụ len qua lối để trống."]
}

static func describe(id: String, hour: float, rain: bool) -> String:
	if not SCENES.has(id):
		return ""
	var phase := 0 if hour < 10.0 else (2 if hour >= 17.0 else 1)
	var text: String = SCENES[id][phase]
	if rain:
		text += " Mưa gõ lên mái, người qua đường nép vào chỗ khô."
	return text
