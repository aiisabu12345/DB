-- BA : ระบบขออนุญาตเดินทางและเบิกค่าใช้จ่าย

-- 1. DEPARTMENT (ใส่ ManagerID ทีหลัง เพราะ Employee ยังไม่มี)
INSERT INTO Department VALUES ('D01','ฝ่ายขาย',NULL);
INSERT INTO Department VALUES ('D02','ฝ่ายบัญชีและการเงิน',NULL);
INSERT INTO Department VALUES ('D03','ฝ่ายจัดซื้อ',NULL);
INSERT INTO Department VALUES ('D04','ฝ่ายขนส่งและคลังสินค้า',NULL);
INSERT INTO Department VALUES ('D05','ฝ่ายบริหาร',NULL);


-- 2. TRANSFERTYPE (ประเภทหลักฐานการโอน)
INSERT INTO TransferType VALUES ('TT01','โอนเงินสำรองจ่าย');
INSERT INTO TransferType VALUES ('TT02','คืนเงินที่ใช้เหลือ');
INSERT INTO TransferType VALUES ('TT03','เบิกเงินที่ใช้เกิน');


-- 3. REQUESTSTATUS (StatusID, StatusName, FlowOrder) : ไม่อนุมัติ อยู่นอก flow
INSERT INTO RequestStatus VALUES ('RS01','รอหัวหน้าแผนกอนุมัติ',1);
INSERT INTO RequestStatus VALUES ('RS02','รอฝ่ายบัญชีอนุมัติ',2);
INSERT INTO RequestStatus VALUES ('RS03','รอผู้บริหารอนุมัติ',3);
INSERT INTO RequestStatus VALUES ('RS04','อนุมัติแล้ว',4);
INSERT INTO RequestStatus VALUES ('RS05','โอนเงินสำรองจ่ายแล้ว',5);
INSERT INTO RequestStatus VALUES ('RS06','ปิดยอดแล้ว',6);
INSERT INTO RequestStatus VALUES ('RS07','ไม่อนุมัติ',NULL);


-- 4. EMPLOYEE (EmpID, FirstName, LastName, Phone, DeptID, HireDate, ResignDate)
INSERT INTO Employee VALUES ('E001','วิชัย','สุขสวัสดิ์','0810000001','D01',TO_DATE('15/01/2019','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E002','อรุณี','ศรีสวัสดิ์','0810000002','D02',TO_DATE('01/06/2019','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E003','ธีรพงศ์','มั่นคง','0810000003','D03',TO_DATE('10/02/2020','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E004','ชนิดา','พรหมมา','0810000004','D04',TO_DATE('05/08/2018','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E005','กิตติพัฒน์','แก้วมณี','0810000005','D01',TO_DATE('01/03/2022','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E006','ปิยะนุช','บุญเรือง','0810000006','D01',TO_DATE('15/07/2022','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E007','สุรเชษฐ์','เพชรรัตน์','0810000007','D02',TO_DATE('02/01/2023','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E008','วรัญญา','ทองดี','0810000008','D02',TO_DATE('20/05/2023','DD/MM/YYYY'),TO_DATE('31/07/2026','DD/MM/YYYY'));
INSERT INTO Employee VALUES ('E009','ณัฐพล','จันทร์เพ็ญ','0810000009','D03',TO_DATE('11/09/2021','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E010','มนัสนันท์','คำสิงห์','0810000010','D01',TO_DATE('01/11/2023','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E011','อนุชา','ศรีวงศ์','0810000011','D04',TO_DATE('01/04/2021','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E012','ศิริพร','แสงจันทร์','0810000012','D03',TO_DATE('16/08/2022','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E013','ประเสริฐ','วัฒนกุล','0810000013','D05',TO_DATE('01/01/2015','DD/MM/YYYY'),NULL);
INSERT INTO Employee VALUES ('E014','สมศักดิ์','รุ่งเรือง','0810000014','D04',TO_DATE('01/02/2016','DD/MM/YYYY'),TO_DATE('31/12/2023','DD/MM/YYYY'));


-- ผู้บริหารแผนกปัจจุบัน (1 แผนก : 1 ผู้บริหาร)
UPDATE Department SET ManagerID = 'E001' WHERE DeptID = 'D01';
UPDATE Department SET ManagerID = 'E002' WHERE DeptID = 'D02';
UPDATE Department SET ManagerID = 'E003' WHERE DeptID = 'D03';
UPDATE Department SET ManagerID = 'E004' WHERE DeptID = 'D04';
UPDATE Department SET ManagerID = 'E013' WHERE DeptID = 'D05';


-- 5. TRAVELREQUEST
-- RequestAmount = ผลรวม AdvanceExpenseItem, ActualAmount = ผลรวม TravelEvidence
INSERT INTO TravelRequest VALUES ('TR001','E005',TO_DATE('01/09/2026','DD/MM/YYYY'),'เข้าพบผู้รับเหมาเพื่อเสนอราคาเหล็กเส้นและปูนซีเมนต์','โครงการหมู่บ้านจัดสรร อ.ศรีราชา จ.ชลบุรี',TO_DATE('03/09/2026','DD/MM/YYYY'),TO_DATE('05/09/2026','DD/MM/YYYY'),3,'RS06','1234567890','กิตติพัฒน์ แก้วมณี',TO_DATE('02/09/2026','DD/MM/YYYY'),4800,4500,'ได้รับใบสั่งซื้อวัสดุจากผู้รับเหมา');
INSERT INTO TravelRequest VALUES ('TR002','E009',TO_DATE('05/09/2026','DD/MM/YYYY'),'เจรจาเงื่อนไขการค้ากับผู้ผลิตปูนซีเมนต์','โรงงานผู้ผลิต อ.แก่งคอย จ.สระบุรี',TO_DATE('10/09/2026','DD/MM/YYYY'),TO_DATE('11/09/2026','DD/MM/YYYY'),2,'RS06','2345678901','ณัฐพล จันทร์เพ็ญ',TO_DATE('08/09/2026','DD/MM/YYYY'),2500,2900,'ได้ส่วนลดราคาสินค้า 5%');
INSERT INTO TravelRequest VALUES ('TR003','E006',TO_DATE('15/09/2026','DD/MM/YYYY'),'สำรวจหน้างานเพื่อประเมินปริมาณวัสดุ','อาคารพาณิชย์ ถ.บางนา-ตราด กม.10',TO_DATE('20/09/2026','DD/MM/YYYY'),TO_DATE('20/09/2026','DD/MM/YYYY'),1,'RS05','3456789012','ปิยะนุช บุญเรือง',TO_DATE('18/09/2026','DD/MM/YYYY'),1100,NULL,'ได้ปริมาณวัสดุสำหรับทำใบเสนอราคา');
INSERT INTO TravelRequest VALUES ('TR004','E011',TO_DATE('25/09/2026','DD/MM/YYYY'),'ติดตามการส่งมอบสินค้าให้ลูกค้า','ไซต์งานก่อสร้าง อ.บางปะอิน จ.พระนครศรีอยุธยา',TO_DATE('01/10/2026','DD/MM/YYYY'),TO_DATE('02/10/2026','DD/MM/YYYY'),2,'RS04','4567890123','อนุชา ศรีวงศ์',NULL,1900,NULL,'ส่งมอบสินค้าครบตามกำหนด');
INSERT INTO TravelRequest VALUES ('TR005','E010',TO_DATE('05/10/2026','DD/MM/YYYY'),'เข้าพบลูกค้ารายใหม่เพื่อเสนอราคากระเบื้อง','ร้านวัสดุก่อสร้าง อ.เมือง จ.เชียงใหม่',TO_DATE('15/10/2026','DD/MM/YYYY'),TO_DATE('17/10/2026','DD/MM/YYYY'),3,'RS07','5678901234','มนัสนันท์ คำสิงห์',NULL,8000,NULL,'ได้ลูกค้ารายใหม่ในภาคเหนือ');
INSERT INTO TravelRequest VALUES ('TR006','E012',TO_DATE('01/11/2026','DD/MM/YYYY'),'เจรจาสัญญาซื้อท่อ PVC ล็อตใหญ่','โรงงานผู้ผลิต นิคมอุตสาหกรรมมาบตาพุด จ.ระยอง',TO_DATE('05/11/2026','DD/MM/YYYY'),TO_DATE('06/11/2026','DD/MM/YYYY'),2,'RS02','6789012345','ศิริพร แสงจันทร์',NULL,2400,NULL,'ได้สัญญาซื้อขายรายปี');

COMMIT;


-- 6. STATUSAPPROVER (StatusID, LineNo, EmpID) : ใครมีสิทธิ์อนุมัติในแต่ละสถานะ
INSERT INTO StatusApprover VALUES ('RS01',1,'E001');
INSERT INTO StatusApprover VALUES ('RS01',2,'E003');
INSERT INTO StatusApprover VALUES ('RS01',3,'E004');
INSERT INTO StatusApprover VALUES ('RS02',1,'E002');
INSERT INTO StatusApprover VALUES ('RS02',2,'E007');
INSERT INTO StatusApprover VALUES ('RS03',1,'E013');


-- 7. TRAVELCOMPANION (RequestID, LineNo, EmpID) : LineNo นับใหม่ในแต่ละคำขอ
INSERT INTO TravelCompanion VALUES ('TR001',1,'E006');
INSERT INTO TravelCompanion VALUES ('TR001',2,'E010');
INSERT INTO TravelCompanion VALUES ('TR002',1,'E012');
INSERT INTO TravelCompanion VALUES ('TR003',1,'E005');
INSERT INTO TravelCompanion VALUES ('TR005',1,'E005');
INSERT INTO TravelCompanion VALUES ('TR006',1,'E009');


-- 8. ADVANCEEXPENSEITEM (RequestID, LineNo, ItemName, UnitPrice, Quantity)
INSERT INTO AdvanceExpenseItem VALUES ('TR001',1,'ค่าน้ำมันรถ',1500,1);
INSERT INTO AdvanceExpenseItem VALUES ('TR001',2,'ค่าที่พัก',1200,2);
INSERT INTO AdvanceExpenseItem VALUES ('TR001',3,'เบี้ยเลี้ยง',300,3);
INSERT INTO AdvanceExpenseItem VALUES ('TR002',1,'ค่าน้ำมันรถ',1200,1);
INSERT INTO AdvanceExpenseItem VALUES ('TR002',2,'ค่าที่พัก',1000,1);
INSERT INTO AdvanceExpenseItem VALUES ('TR002',3,'ค่าทางด่วน',150,2);
INSERT INTO AdvanceExpenseItem VALUES ('TR003',1,'ค่าแท็กซี่',400,2);
INSERT INTO AdvanceExpenseItem VALUES ('TR003',2,'เบี้ยเลี้ยง',300,1);
INSERT INTO AdvanceExpenseItem VALUES ('TR004',1,'ค่าน้ำมันรถ',1000,1);
INSERT INTO AdvanceExpenseItem VALUES ('TR004',2,'ค่าที่พัก',900,1);
INSERT INTO AdvanceExpenseItem VALUES ('TR005',1,'ค่าตั๋วเครื่องบินไป-กลับ',2500,2);
INSERT INTO AdvanceExpenseItem VALUES ('TR005',2,'ค่าที่พัก',1500,2);
INSERT INTO AdvanceExpenseItem VALUES ('TR006',1,'ค่าน้ำมันรถ',1300,1);
INSERT INTO AdvanceExpenseItem VALUES ('TR006',2,'ค่าที่พัก',1100,1);


-- 9. APPROVALSIGNATURE (RequestID, LineNo, StatusID, EmpID, SignDate, Result, RejectReason)
-- StatusID = สถานะที่ลงนาม , ผู้ลงนามต้องอยู่ใน StatusApprover ของสถานะนั้น
INSERT INTO ApprovalSignature VALUES ('TR001',1,'RS01','E001',TO_DATE('01/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR001',2,'RS02','E002',TO_DATE('02/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR001',3,'RS03','E013',TO_DATE('02/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR002',1,'RS01','E003',TO_DATE('06/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR002',2,'RS02','E007',TO_DATE('07/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR002',3,'RS03','E013',TO_DATE('08/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR003',1,'RS01','E001',TO_DATE('16/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR003',2,'RS02','E002',TO_DATE('17/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR003',3,'RS03','E013',TO_DATE('17/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR004',1,'RS01','E004',TO_DATE('26/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR004',2,'RS02','E007',TO_DATE('28/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR004',3,'RS03','E013',TO_DATE('29/09/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR005',1,'RS01','E001',TO_DATE('06/10/2026','DD/MM/YYYY'),'อนุมัติ',NULL);
INSERT INTO ApprovalSignature VALUES ('TR005',2,'RS02','E002',TO_DATE('08/10/2026','DD/MM/YYYY'),'ไม่อนุมัติ','งบประมาณเดินทางของไตรมาสนี้เกินวงเงินที่กำหนด');
INSERT INTO ApprovalSignature VALUES ('TR006',1,'RS01','E003',TO_DATE('02/11/2026','DD/MM/YYYY'),'อนุมัติ',NULL);


-- 10. TRAVELEVIDENCE (หลักฐานการเดินทาง : RequestID, LineNo, UsedDate, ItemName, Amount, SlipURL)
INSERT INTO TravelEvidence VALUES ('TR001',1,TO_DATE('03/09/2026 08:15','DD/MM/YYYY HH24:MI'),'ค่าน้ำมันรถ',1350,'https://slip.example.com/tr001-1.jpg');
INSERT INTO TravelEvidence VALUES ('TR001',2,TO_DATE('05/09/2026 11:00','DD/MM/YYYY HH24:MI'),'ค่าที่พัก 2 คืน',2400,'https://slip.example.com/tr001-2.jpg');
INSERT INTO TravelEvidence VALUES ('TR001',3,TO_DATE('05/09/2026 12:30','DD/MM/YYYY HH24:MI'),'ค่าอาหาร',750,'https://slip.example.com/tr001-3.jpg');
INSERT INTO TravelEvidence VALUES ('TR002',1,TO_DATE('10/09/2026 07:40','DD/MM/YYYY HH24:MI'),'ค่าน้ำมันรถ',1400,'https://slip.example.com/tr002-1.jpg');
INSERT INTO TravelEvidence VALUES ('TR002',2,TO_DATE('11/09/2026 10:30','DD/MM/YYYY HH24:MI'),'ค่าที่พัก 1 คืน',1000,'https://slip.example.com/tr002-2.jpg');
INSERT INTO TravelEvidence VALUES ('TR002',3,TO_DATE('11/09/2026 16:20','DD/MM/YYYY HH24:MI'),'ค่าทางด่วน',300,'https://slip.example.com/tr002-3.jpg');
INSERT INTO TravelEvidence VALUES ('TR002',4,TO_DATE('11/09/2026 17:00','DD/MM/YYYY HH24:MI'),'ค่าจอดรถ',200,'https://slip.example.com/tr002-4.jpg');


-- 11. TRANSFEREVIDENCE
-- TR001 ใช้ไม่หมด (4800-4500) -> คืน 300 , TR002 ใช้เกิน (2900-2500) -> เบิกเพิ่ม 400
INSERT INTO TransferEvidence VALUES ('TE001','TR001','TT01',TO_DATE('02/09/2026 14:30','DD/MM/YYYY HH24:MI'),4800,'ธนาคารกสิกรไทย','กิตติพัฒน์ แก้วมณี','KB20260902001','https://slip.example.com/te001.jpg');
INSERT INTO TransferEvidence VALUES ('TE002','TR001','TT02',TO_DATE('07/09/2026 10:00','DD/MM/YYYY HH24:MI'),300,'ธนาคารไทยพาณิชย์','บริษัท วัสดุก่อสร้าง จำกัด','SCB20260907001','https://slip.example.com/te002.jpg');
INSERT INTO TransferEvidence VALUES ('TE003','TR002','TT01',TO_DATE('08/09/2026 15:00','DD/MM/YYYY HH24:MI'),2500,'ธนาคารกรุงเทพ','ณัฐพล จันทร์เพ็ญ','BBL20260908001','https://slip.example.com/te003.jpg');
INSERT INTO TransferEvidence VALUES ('TE004','TR002','TT03',TO_DATE('14/09/2026 11:30','DD/MM/YYYY HH24:MI'),400,'ธนาคารกรุงเทพ','ณัฐพล จันทร์เพ็ญ','BBL20260914001','https://slip.example.com/te004.jpg');
INSERT INTO TransferEvidence VALUES ('TE005','TR003','TT01',TO_DATE('18/09/2026 13:45','DD/MM/YYYY HH24:MI'),1100,'ธนาคารกรุงไทย','ปิยะนุช บุญเรือง','KTB20260918001','https://slip.example.com/te005.jpg');

COMMIT;
