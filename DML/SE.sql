-- SE : ระบบประกาศของหาย-ของพบ คณะวิทยาศาสตร์

-- 1. USERROLE
INSERT INTO UserRole VALUES ('R01','Admin');
INSERT INTO UserRole VALUES ('R02','User');


-- 2. CATEGORY
INSERT INTO Category VALUES ('CT01','อุปกรณ์อิเล็กทรอนิกส์');
INSERT INTO Category VALUES ('CT02','กระเป๋า');
INSERT INTO Category VALUES ('CT03','บัตร/เอกสาร');
INSERT INTO Category VALUES ('CT04','กุญแจ');
INSERT INTO Category VALUES ('CT05','เครื่องเขียน');
INSERT INTO Category VALUES ('CT06','เครื่องแต่งกาย');
INSERT INTO Category VALUES ('CT07','ขวดน้ำ/แก้วน้ำ');
INSERT INTO Category VALUES ('CT08','เครื่องประดับ');


-- 3. POSTSTATUS (สถานะประกาศพบ PS01-PS03 / ประกาศหาของหาย PS04-PS05 / ใช้ร่วมกัน PS06)
INSERT INTO PostStatus VALUES ('PS01','รอเจ้าของ');
INSERT INTO PostStatus VALUES ('PS02','กำลังตรวจสอบ');
INSERT INTO PostStatus VALUES ('PS03','คืนแล้ว');
INSERT INTO PostStatus VALUES ('PS04','กำลังตามหา');
INSERT INTO PostStatus VALUES ('PS05','พบแล้ว');
INSERT INTO PostStatus VALUES ('PS06','ปิดประกาศ');


-- 4. CLAIMSTATUS
INSERT INTO ClaimStatus VALUES ('CS01','รอพิจารณา');
INSERT INTO ClaimStatus VALUES ('CS02','อนุมัติ');
INSERT INTO ClaimStatus VALUES ('CS03','ปฏิเสธ');


-- 5. USERS
INSERT INTO Users VALUES ('U001','วีริศ','เหล่าลดา','0811111111','weerit.l@kmitl.ac.th','อาคารวิทยาศาสตร์ 1 ห้องธุรการ','R01');
INSERT INTO Users VALUES ('U002','ศรยุทธ','ชัยชมภู','0822222222','sornyut.c@kmitl.ac.th','อาคารวิทยาศาสตร์ 2 ห้อง 201','R01');
INSERT INTO Users VALUES ('U003','สาธุ','ญาณะณิสสร','0833333333','sathu.y@kmitl.ac.th','หอพักนักศึกษา ตึก C ห้อง 305','R02');
INSERT INTO Users VALUES ('U004','ศิวกร','กลิ่นหอมอุทิศ','0844444444','siwakon.k@kmitl.ac.th','ซ.ฉลองกรุง 1 แขวงลาดกระบัง กรุงเทพฯ 10520','R02');
INSERT INTO Users VALUES ('U005','กมลชนก','ศรีสุข','0855555555','kamonchanok.s@kmitl.ac.th','หอพักนักศึกษา ตึก A ห้อง 112','R02');
INSERT INTO Users VALUES ('U006','ธนกร','วงศ์ใหญ่','0866666666','thanakorn.w@kmitl.ac.th','คอนโดลาดกระบัง ห้อง 1208','R02');
INSERT INTO Users VALUES ('U007','พิมพ์ชนก','ใจดี','0877777777','pimchanok.j@kmitl.ac.th','ภาควิชาเคมี ห้องพักอาจารย์','R02');
INSERT INTO Users VALUES ('U008','ณัฐวุฒิ','แก้วกาญจน์','0888888888','nattawut.k@kmitl.ac.th','หอพักนักศึกษา ตึก B ห้อง 418','R02');


-- 6. FOUNDPOST (โพสต์โดยแอดมิน U001, U002)
INSERT INTO FoundPost VALUES ('FP001','พบโทรศัพท์มือถือสีดำ','iPhone 13 สีดำ','สมชาย ใจงาม','0912345678','somchai.j@kmitl.ac.th','ภาควิชาฟิสิกส์','https://img.example.com/fp001.jpg','ห้องเรียน 301 อาคารวิทยาศาสตร์ 1','PS03',TO_DATE('02/09/2026','DD/MM/YYYY'),TO_DATE('01/09/2026','DD/MM/YYYY'),'U001');
INSERT INTO FoundPost VALUES ('FP002','พบกระเป๋าสตางค์สีน้ำตาล','กระเป๋าสตางค์หนัง','สุดา มีสุข','0923456789','suda.m@kmitl.ac.th','หอพักนักศึกษา ตึก A','https://img.example.com/fp002.jpg','โรงอาหารคณะวิทยาศาสตร์','PS02',TO_DATE('05/09/2026','DD/MM/YYYY'),TO_DATE('05/09/2026','DD/MM/YYYY'),'U001');
INSERT INTO FoundPost VALUES ('FP003','พบบัตรนักศึกษา','บัตรนักศึกษา','วิชัย ทองดี','0934567890','wichai.t@kmitl.ac.th','ภาควิชาคณิตศาสตร์','https://img.example.com/fp003.jpg','ลานจอดรถหน้าคณะ','PS02',TO_DATE('10/09/2026','DD/MM/YYYY'),TO_DATE('09/09/2026','DD/MM/YYYY'),'U002');
INSERT INTO FoundPost VALUES ('FP004','พบพวงกุญแจรถจักรยานยนต์','กุญแจรถ Honda','มาลี สวยงาม','0945678901','malee.s@kmitl.ac.th','ภาควิชาชีววิทยา','https://img.example.com/fp004.jpg','ห้องปฏิบัติการชีววิทยา','PS01',TO_DATE('15/09/2026','DD/MM/YYYY'),TO_DATE('14/09/2026','DD/MM/YYYY'),'U002');
INSERT INTO FoundPost VALUES ('FP005','พบหูฟังไร้สาย','AirPods Pro','ประยุทธ ขยันดี','0956789012','prayut.k@kmitl.ac.th','ภาควิชาเคมี','https://img.example.com/fp005.jpg','ห้องสมุดคณะวิทยาศาสตร์ ชั้น 2','PS02',TO_DATE('20/09/2026','DD/MM/YYYY'),TO_DATE('20/09/2026','DD/MM/YYYY'),'U001');
INSERT INTO FoundPost VALUES ('FP006','พบเสื้อแจ็คเก็ตสีกรม','เสื้อแจ็คเก็ต','อรวรรณ ศรีทอง','0967890123','orawan.s@kmitl.ac.th','ภาควิชาสถิติ','https://img.example.com/fp006.jpg','ห้องเรียน 105 อาคารวิทยาศาสตร์ 2','PS01',TO_DATE('25/09/2026','DD/MM/YYYY'),TO_DATE('23/09/2026','DD/MM/YYYY'),'U002');
INSERT INTO FoundPost VALUES ('FP007','พบกระบอกน้ำสแตนเลส','กระบอกน้ำ Tumbler','กิตติ พรหมมา','0978901234','kitti.p@kmitl.ac.th','ภาควิชาวิทยาการคอมพิวเตอร์','https://img.example.com/fp007.jpg','ห้องปฏิบัติการคอมพิวเตอร์ 1','PS03',TO_DATE('01/10/2026','DD/MM/YYYY'),TO_DATE('30/09/2026','DD/MM/YYYY'),'U001');
INSERT INTO FoundPost VALUES ('FP008','พบแหวนเงิน','แหวนเงินสลักชื่อ','นภา แสงทอง','0989012345','napa.s@kmitl.ac.th','ภาควิชาฟิสิกส์','https://img.example.com/fp008.jpg','ห้องน้ำหญิง ชั้น 3 อาคารวิทยาศาสตร์ 1','PS01',TO_DATE('05/10/2026','DD/MM/YYYY'),TO_DATE('05/10/2026','DD/MM/YYYY'),'U002');


-- 7. LOSTPOST (สร้างโดยผู้ใช้งาน)
INSERT INTO LostPost VALUES ('LP001','ตามหาโทรศัพท์ iPhone สีดำ หายแถวอาคาร 1',TO_DATE('01/09/2026','DD/MM/YYYY'),'PS05','U003');
INSERT INTO LostPost VALUES ('LP002','ตามหากระเป๋าสตางค์สีน้ำตาล มีบัตรประชาชน',TO_DATE('05/09/2026','DD/MM/YYYY'),'PS04','U004');
INSERT INTO LostPost VALUES ('LP003','ตามหาโน้ตบุ๊ก Asus สีเทา',TO_DATE('12/09/2026','DD/MM/YYYY'),'PS04','U005');
INSERT INTO LostPost VALUES ('LP004','ตามหาหูฟัง AirPods Pro',TO_DATE('19/09/2026','DD/MM/YYYY'),'PS04','U006');
INSERT INTO LostPost VALUES ('LP005','ตามหาเครื่องคิดเลข Casio fx-991',TO_DATE('22/09/2026','DD/MM/YYYY'),'PS04','U007');
INSERT INTO LostPost VALUES ('LP006','ตามหากระบอกน้ำสแตนเลสสีเขียว',TO_DATE('30/09/2026','DD/MM/YYYY'),'PS05','U008');

COMMIT;


-- 8. CLAIMREQUEST (คำขอของคืน : 1 ประกาศพบ มีได้หลายคำขอ)
INSERT INTO ClaimRequest VALUES ('RQ001','FP001','U003','CS02',TO_DATE('02/09/2026','DD/MM/YYYY'),'เครื่องมีเคสลายแมว รหัสปลดล็อกยืนยันได้');
INSERT INTO ClaimRequest VALUES ('RQ002','FP002','U004','CS01',TO_DATE('06/09/2026','DD/MM/YYYY'),'ในกระเป๋ามีบัตรประชาชนชื่อศิวกร');
INSERT INTO ClaimRequest VALUES ('RQ003','FP002','U008','CS03',TO_DATE('06/09/2026','DD/MM/YYYY'),'กระเป๋าสีน้ำตาลเหมือนของผม');
INSERT INTO ClaimRequest VALUES ('RQ004','FP005','U006','CS01',TO_DATE('21/09/2026','DD/MM/YYYY'),'เคสหูฟังมีสติกเกอร์รูปดาว');
INSERT INTO ClaimRequest VALUES ('RQ005','FP005','U005','CS03',TO_DATE('21/09/2026','DD/MM/YYYY'),'น่าจะเป็นหูฟังของฉัน');
INSERT INTO ClaimRequest VALUES ('RQ006','FP007','U008','CS02',TO_DATE('01/10/2026','DD/MM/YYYY'),'กระบอกน้ำสีเขียว มีรอยบุบด้านล่าง');
INSERT INTO ClaimRequest VALUES ('RQ007','FP003','U007','CS01',TO_DATE('11/09/2026','DD/MM/YYYY'),'รับแทนนักศึกษาในที่ปรึกษา');


-- 9. FOUNDPOSTCATEGORY
-- (FoundPostID, LineNo, CategoryID) : LineNo นับใหม่ในแต่ละประกาศ
INSERT INTO FoundPostCategory VALUES ('FP001',1,'CT01');
INSERT INTO FoundPostCategory VALUES ('FP002',1,'CT02');
INSERT INTO FoundPostCategory VALUES ('FP002',2,'CT03');
INSERT INTO FoundPostCategory VALUES ('FP003',1,'CT03');
INSERT INTO FoundPostCategory VALUES ('FP004',1,'CT04');
INSERT INTO FoundPostCategory VALUES ('FP005',1,'CT01');
INSERT INTO FoundPostCategory VALUES ('FP006',1,'CT06');
INSERT INTO FoundPostCategory VALUES ('FP007',1,'CT07');
INSERT INTO FoundPostCategory VALUES ('FP008',1,'CT08');


-- 10. LOSTPOSTCATEGORY
INSERT INTO LostPostCategory VALUES ('LP001',1,'CT01');
INSERT INTO LostPostCategory VALUES ('LP002',1,'CT02');
INSERT INTO LostPostCategory VALUES ('LP002',2,'CT03');
INSERT INTO LostPostCategory VALUES ('LP003',1,'CT01');
INSERT INTO LostPostCategory VALUES ('LP004',1,'CT01');
INSERT INTO LostPostCategory VALUES ('LP005',1,'CT01');
INSERT INTO LostPostCategory VALUES ('LP005',2,'CT05');
INSERT INTO LostPostCategory VALUES ('LP006',1,'CT07');

COMMIT;

