-- BA : ระบบขออนุญาตเดินทางและเบิกค่าใช้จ่าย
-- SET SERVEROUTPUT ON
-- flow สถานะอ่านจาก RequestStatus.FlowOrder : สถานะที่มีผู้อนุมัติใน StatusApprover = ขั้นลงนาม
-- RS04 อนุมัติแล้ว , RS05 โอนเงินสำรองจ่ายแล้ว , RS06 ปิดยอดแล้ว , RS07 ไม่อนุมัติ


-- 1. Helper : สถานะถัดไปใน flow / ยอดรวมค่าใช้จ่าย

CREATE OR REPLACE FUNCTION fn_next_status (
    p_statusid IN VARCHAR2
) RETURN VARCHAR2 AS
    v_next RequestStatus.StatusID%TYPE;
BEGIN
    SELECT StatusID INTO v_next
      FROM (SELECT StatusID
              FROM RequestStatus
             WHERE FlowOrder > (SELECT FlowOrder FROM RequestStatus WHERE StatusID = p_statusid)
             ORDER BY FlowOrder)
     WHERE ROWNUM = 1;
    RETURN v_next;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;
/

-- คำนวณ RequestAmount / ActualAmount ใหม่จาก weak table
CREATE OR REPLACE PROCEDURE sp_recalc_amount (
    p_requestid IN VARCHAR2
) AS
BEGIN
    UPDATE TravelRequest r
       SET RequestAmount = (SELECT NVL(SUM(UnitPrice * Quantity), 0)
                              FROM AdvanceExpenseItem i WHERE i.RequestID = r.RequestID),
           ActualAmount  = (SELECT SUM(Amount)
                              FROM TravelEvidence e WHERE e.RequestID = r.RequestID)
     WHERE RequestID = p_requestid;
END;
/


-- 2. TravelRequest : สร้างคำขอ / เพิ่มรายการค่าใช้จ่ายล่วงหน้า / เพิ่มผู้ร่วมเดินทาง
--    แก้ไขรายการได้เฉพาะตอนยังไม่มีใครลงนาม

CREATE OR REPLACE PROCEDURE sp_create_request (
    p_requestid   IN VARCHAR2,
    p_empid       IN VARCHAR2,
    p_purpose     IN VARCHAR2,
    p_destination IN VARCHAR2,
    p_startdate   IN DATE,
    p_enddate     IN DATE,
    p_accountno   IN VARCHAR2,
    p_accountname IN VARCHAR2,
    p_expected    IN VARCHAR2
) AS
    v_resign Employee.ResignDate%TYPE;
    v_first  RequestStatus.StatusID%TYPE;
BEGIN
    SELECT ResignDate INTO v_resign FROM Employee WHERE EmpID = p_empid;
    IF v_resign IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20100, 'พนักงาน ' || p_empid || ' ลาออกแล้ว');
    END IF;

    SELECT StatusID INTO v_first
      FROM RequestStatus
     WHERE FlowOrder = (SELECT MIN(FlowOrder) FROM RequestStatus);

    INSERT INTO TravelRequest (RequestID, EmpID, WriteDate, Purpose, Destination, StartDate, EndDate,
                               TotalDays, StatusID, AccountNo, AccountName, DisburseDate,
                               RequestAmount, ActualAmount, ExpectedResult)
    VALUES (p_requestid, p_empid, TRUNC(SYSDATE), p_purpose, p_destination, p_startdate, p_enddate,
            p_enddate - p_startdate + 1, v_first, p_accountno, p_accountname, NULL,
            0, NULL, p_expected);
    DBMS_OUTPUT.PUT_LINE('สร้างคำขออนุมัติการเดินทางเรียบร้อย: ' || p_requestid);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบพนักงาน: ' || p_empid);
END;
/

CREATE OR REPLACE PROCEDURE sp_add_advance_item (
    p_requestid IN VARCHAR2,
    p_itemname  IN VARCHAR2,
    p_unitprice IN NUMBER,
    p_quantity  IN NUMBER
) AS
    v_signed NUMBER;
    v_line   NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_signed FROM ApprovalSignature WHERE RequestID = p_requestid;
    IF v_signed > 0 THEN
        RAISE_APPLICATION_ERROR(-20101, 'คำขอ ' || p_requestid || ' เริ่มลงนามแล้ว แก้รายการไม่ได้');
    END IF;

    SELECT NVL(MAX(LineNo), 0) + 1 INTO v_line
      FROM AdvanceExpenseItem WHERE RequestID = p_requestid;
    INSERT INTO AdvanceExpenseItem VALUES (p_requestid, v_line, p_itemname, p_unitprice, p_quantity);
    sp_recalc_amount(p_requestid);
    DBMS_OUTPUT.PUT_LINE('เพิ่มรายการค่าใช้จ่ายล่วงหน้า ' || p_itemname || ' ให้ ' || p_requestid);
END;
/

CREATE OR REPLACE PROCEDURE sp_add_companion (
    p_requestid IN VARCHAR2,
    p_empid     IN VARCHAR2
) AS
    v_owner  TravelRequest.EmpID%TYPE;
    v_resign Employee.ResignDate%TYPE;
    v_line   NUMBER;
BEGIN
    SELECT EmpID INTO v_owner FROM TravelRequest WHERE RequestID = p_requestid;
    SELECT ResignDate INTO v_resign FROM Employee WHERE EmpID = p_empid;
    IF v_owner = p_empid THEN
        RAISE_APPLICATION_ERROR(-20102, 'ผู้ขอไม่ต้องใส่ตัวเองเป็นผู้ร่วมเดินทาง');
    ELSIF v_resign IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20100, 'พนักงาน ' || p_empid || ' ลาออกแล้ว');
    END IF;

    SELECT NVL(MAX(LineNo), 0) + 1 INTO v_line
      FROM TravelCompanion WHERE RequestID = p_requestid;
    INSERT INTO TravelCompanion VALUES (p_requestid, v_line, p_empid);
    DBMS_OUTPUT.PUT_LINE('เพิ่มผู้ร่วมเดินทาง ' || p_empid || ' ใน ' || p_requestid);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE(p_empid || ' เป็นผู้ร่วมเดินทางของ ' || p_requestid || ' อยู่แล้ว');
END;
/


-- 3. ApprovalSignature : ลงนามอนุมัติตาม flow
--    - ผู้ลงนามต้องอยู่ใน StatusApprover ของสถานะปัจจุบัน และยังไม่ลาออก
--    - ขั้นแรกของ flow (หัวหน้าแผนก) ต้องเป็นผู้บริหารแผนกของผู้ขอ
--    - ห้ามลงนามคำขอของตัวเอง
--    - อนุมัติ -> สถานะถัดไป , ไม่อนุมัติ -> RS07

CREATE OR REPLACE PROCEDURE sp_sign_request (
    p_requestid IN VARCHAR2,
    p_empid     IN VARCHAR2,
    p_approve   IN NUMBER,       -- 1 = อนุมัติ, 0 = ไม่อนุมัติ
    p_reason    IN VARCHAR2 DEFAULT NULL
) AS
    v_status   TravelRequest.StatusID%TYPE;
    v_owner    TravelRequest.EmpID%TYPE;
    v_flow     RequestStatus.FlowOrder%TYPE;
    v_minflow  RequestStatus.FlowOrder%TYPE;
    v_allowed  NUMBER;
    v_manager  Department.ManagerID%TYPE;
    v_resign   Employee.ResignDate%TYPE;
    v_line     NUMBER;
BEGIN
    SELECT r.StatusID, r.EmpID, s.FlowOrder, d.ManagerID
      INTO v_status, v_owner, v_flow, v_manager
      FROM TravelRequest r
      JOIN RequestStatus s ON s.StatusID = r.StatusID
      JOIN Employee e      ON e.EmpID    = r.EmpID
      JOIN Department d    ON d.DeptID   = e.DeptID
     WHERE r.RequestID = p_requestid
       FOR UPDATE OF r.StatusID;

    SELECT COUNT(*) INTO v_allowed
      FROM StatusApprover WHERE StatusID = v_status AND EmpID = p_empid;
    SELECT ResignDate INTO v_resign FROM Employee WHERE EmpID = p_empid;
    SELECT MIN(FlowOrder) INTO v_minflow FROM RequestStatus;

    IF v_allowed = 0 THEN
        RAISE_APPLICATION_ERROR(-20110, p_empid || ' ไม่มีสิทธิ์ลงนามในสถานะ ' || v_status);
    ELSIF v_resign IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20100, 'พนักงาน ' || p_empid || ' ลาออกแล้ว');
    ELSIF p_empid = v_owner THEN
        RAISE_APPLICATION_ERROR(-20111, 'ห้ามลงนามคำขอของตัวเอง');
    ELSIF v_flow = v_minflow AND p_empid <> NVL(v_manager, '-') THEN
        RAISE_APPLICATION_ERROR(-20112, 'ขั้นแรกต้องลงนามโดยหัวหน้าแผนกของผู้ขอ (' || v_manager || ')');
    ELSIF p_approve = 0 AND p_reason IS NULL THEN
        RAISE_APPLICATION_ERROR(-20113, 'ไม่อนุมัติต้องระบุเหตุผล');
    END IF;

    SELECT NVL(MAX(LineNo), 0) + 1 INTO v_line
      FROM ApprovalSignature WHERE RequestID = p_requestid;
    INSERT INTO ApprovalSignature VALUES (p_requestid, v_line, v_status, p_empid, TRUNC(SYSDATE),
                                          CASE WHEN p_approve = 1 THEN N'อนุมัติ' ELSE N'ไม่อนุมัติ' END,
                                          p_reason);

    UPDATE TravelRequest
       SET StatusID = CASE WHEN p_approve = 1 THEN fn_next_status(v_status) ELSE 'RS07' END
     WHERE RequestID = p_requestid;

    DBMS_OUTPUT.PUT_LINE(p_empid || CASE WHEN p_approve = 1 THEN ' อนุมัติ ' ELSE ' ไม่อนุมัติ ' END
                         || p_requestid || ' (ขั้น ' || v_status || ')');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบคำขอหรือพนักงาน: ' || p_requestid || ' / ' || p_empid);
END;
/


-- 4. TransferEvidence / TravelEvidence : โอนเงินสำรองจ่าย -> ใส่หลักฐานการเดินทาง -> ปิดยอด

-- โอนเงินสำรองจ่าย (ต้องอนุมัติครบแล้ว) ยอดโอน = RequestAmount
CREATE OR REPLACE PROCEDURE sp_transfer_advance (
    p_evidenceid IN VARCHAR2,
    p_requestid  IN VARCHAR2,
    p_bank       IN VARCHAR2,
    p_refno      IN VARCHAR2,
    p_slipurl    IN VARCHAR2
) AS
    v_status TravelRequest.StatusID%TYPE;
    v_amount TravelRequest.RequestAmount%TYPE;
    v_name   TravelRequest.AccountName%TYPE;
BEGIN
    SELECT StatusID, RequestAmount, AccountName INTO v_status, v_amount, v_name
      FROM TravelRequest WHERE RequestID = p_requestid FOR UPDATE;
    IF v_status <> 'RS04' THEN
        RAISE_APPLICATION_ERROR(-20120, 'คำขอ ' || p_requestid || ' ยังไม่อนุมัติครบ');
    END IF;

    INSERT INTO TransferEvidence VALUES (p_evidenceid, p_requestid, 'TT01', SYSDATE, v_amount,
                                         p_bank, v_name, p_refno, p_slipurl);
    UPDATE TravelRequest
       SET StatusID = fn_next_status(v_status), DisburseDate = TRUNC(SYSDATE)
     WHERE RequestID = p_requestid;
    DBMS_OUTPUT.PUT_LINE('โอนเงินสำรองจ่าย ' || v_amount || ' บาท ให้ ' || p_requestid);
END;
/

-- เพิ่มหลักฐานการเดินทาง (ใช้เงินจริง) ได้หลังโอนเงินสำรองจ่ายแล้ว
CREATE OR REPLACE PROCEDURE sp_add_travel_evidence (
    p_requestid IN VARCHAR2,
    p_useddate  IN DATE,
    p_itemname  IN VARCHAR2,
    p_amount    IN NUMBER,
    p_slipurl   IN VARCHAR2
) AS
    v_status TravelRequest.StatusID%TYPE;
    v_line   NUMBER;
BEGIN
    SELECT StatusID INTO v_status FROM TravelRequest WHERE RequestID = p_requestid;
    IF v_status <> 'RS05' THEN
        RAISE_APPLICATION_ERROR(-20121, 'คำขอ ' || p_requestid || ' ยังไม่ได้รับเงินสำรองจ่าย หรือปิดยอดแล้ว');
    END IF;

    SELECT NVL(MAX(LineNo), 0) + 1 INTO v_line
      FROM TravelEvidence WHERE RequestID = p_requestid;
    INSERT INTO TravelEvidence VALUES (p_requestid, v_line, p_useddate, p_itemname, p_amount, p_slipurl);
    sp_recalc_amount(p_requestid);
    DBMS_OUTPUT.PUT_LINE('เพิ่มหลักฐานการเดินทาง ' || p_itemname || ' ' || p_amount || ' บาท');
END;
/

-- ปิดยอด : ใช้เกิน -> เบิกเพิ่ม (TT03) , ใช้ไม่หมด -> คืนเงิน (TT02) , พอดี -> ไม่ต้องโอน
CREATE OR REPLACE PROCEDURE sp_close_request (
    p_evidenceid IN VARCHAR2,
    p_requestid  IN VARCHAR2,
    p_bank       IN VARCHAR2,
    p_owner      IN VARCHAR2,
    p_refno      IN VARCHAR2,
    p_slipurl    IN VARCHAR2
) AS
    v_status TravelRequest.StatusID%TYPE;
    v_req    TravelRequest.RequestAmount%TYPE;
    v_act    TravelRequest.ActualAmount%TYPE;
    v_diff   NUMBER;
BEGIN
    SELECT StatusID, RequestAmount, NVL(ActualAmount, 0) INTO v_status, v_req, v_act
      FROM TravelRequest WHERE RequestID = p_requestid FOR UPDATE;
    IF v_status <> 'RS05' THEN
        RAISE_APPLICATION_ERROR(-20122, 'คำขอ ' || p_requestid || ' ปิดยอดไม่ได้ในสถานะ ' || v_status);
    END IF;

    v_diff := v_act - v_req;
    IF v_diff > 0 THEN
        INSERT INTO TransferEvidence VALUES (p_evidenceid, p_requestid, 'TT03', SYSDATE, v_diff,
                                             p_bank, p_owner, p_refno, p_slipurl);
        DBMS_OUTPUT.PUT_LINE('ใช้เกิน เบิกเพิ่ม ' || v_diff || ' บาท');
    ELSIF v_diff < 0 THEN
        INSERT INTO TransferEvidence VALUES (p_evidenceid, p_requestid, 'TT02', SYSDATE, -v_diff,
                                             p_bank, p_owner, p_refno, p_slipurl);
        DBMS_OUTPUT.PUT_LINE('ใช้ไม่หมด คืนเงิน ' || -v_diff || ' บาท');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ใช้พอดี ไม่ต้องโอน');
    END IF;

    UPDATE TravelRequest SET StatusID = fn_next_status(v_status) WHERE RequestID = p_requestid;
    DBMS_OUTPUT.PUT_LINE('ปิดยอดคำขอเรียบร้อย: ' || p_requestid);
END;
/


-- 5. Employee / Department : เปลี่ยนผู้บริหารแผนก / พนักงานลาออก

-- เปลี่ยนผู้บริหาร : ปิดประวัติเดิม เปิดประวัติใหม่ และสลับสิทธิ์ลงนามขั้นหัวหน้าแผนก
CREATE OR REPLACE PROCEDURE sp_change_manager (
    p_deptid    IN VARCHAR2,
    p_newmgr    IN VARCHAR2,
    p_startdate IN DATE
) AS
    v_oldmgr  Department.ManagerID%TYPE;
    v_newdept Employee.DeptID%TYPE;
    v_first   RequestStatus.StatusID%TYPE;
    v_line    NUMBER;
BEGIN
    SELECT ManagerID INTO v_oldmgr FROM Department WHERE DeptID = p_deptid FOR UPDATE;
    SELECT DeptID INTO v_newdept FROM Employee WHERE EmpID = p_newmgr;
    IF v_newdept <> p_deptid THEN
        RAISE_APPLICATION_ERROR(-20130, p_newmgr || ' ไม่ได้สังกัดแผนก ' || p_deptid);
    END IF;

    UPDATE ManagementHistory
       SET EndDate = p_startdate - 1
     WHERE DeptID = p_deptid AND EndDate IS NULL;

    SELECT NVL(MAX(LineNo), 0) + 1 INTO v_line FROM ManagementHistory WHERE DeptID = p_deptid;
    INSERT INTO ManagementHistory VALUES (p_deptid, v_line, p_newmgr, p_startdate, NULL);
    UPDATE Department SET ManagerID = p_newmgr WHERE DeptID = p_deptid;

    -- ไม่ลบสิทธิ์ของผู้บริหารเดิม เพราะ ApprovalSignature เก่าอ้างอิงอยู่
    -- (sp_sign_request บังคับขั้นแรกให้เป็นผู้บริหารปัจจุบันอยู่แล้ว)
    SELECT StatusID INTO v_first
      FROM RequestStatus WHERE FlowOrder = (SELECT MIN(FlowOrder) FROM RequestStatus);
    SELECT NVL(MAX(LineNo), 0) + 1 INTO v_line FROM StatusApprover WHERE StatusID = v_first;
    BEGIN
        INSERT INTO StatusApprover VALUES (v_first, v_line, p_newmgr);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            NULL;   -- ผู้บริหารใหม่มีสิทธิ์ขั้นแรกอยู่แล้ว
    END;

    DBMS_OUTPUT.PUT_LINE('เปลี่ยนผู้บริหาร ' || p_deptid || ' : ' || NVL(v_oldmgr, '-') || ' -> ' || p_newmgr);
END;
/

-- พนักงานลาออก : ถ้าเป็นผู้บริหารแผนกอยู่ ต้องเปลี่ยนผู้บริหารก่อน (สิทธิ์ลงนามเดิมเก็บไว้เป็นประวัติ sp_sign_request กันคนลาออกเอง)
CREATE OR REPLACE PROCEDURE sp_resign_employee (
    p_empid      IN VARCHAR2,
    p_resigndate IN DATE
) AS
    v_mgr NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_mgr FROM Department WHERE ManagerID = p_empid;
    IF v_mgr > 0 THEN
        RAISE_APPLICATION_ERROR(-20131, p_empid || ' เป็นผู้บริหารแผนกอยู่ ให้ sp_change_manager ก่อน');
    END IF;

    UPDATE Employee SET ResignDate = p_resigndate WHERE EmpID = p_empid;
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบพนักงาน: ' || p_empid);
        RETURN;
    END IF;
    DBMS_OUTPUT.PUT_LINE('บันทึกการลาออกเรียบร้อย: ' || p_empid);
END;
/


-- 6. Report : สรุปคำขอ 1 ฉบับ

CREATE OR REPLACE PROCEDURE sp_request_summary (
    p_requestid IN VARCHAR2
) AS
    v_r TravelRequest%ROWTYPE;
    v_name   NVARCHAR2(200);
    v_status RequestStatus.StatusName%TYPE;
BEGIN
    SELECT * INTO v_r FROM TravelRequest WHERE RequestID = p_requestid;
    SELECT e.FirstName || ' ' || e.LastName INTO v_name FROM Employee e WHERE e.EmpID = v_r.EmpID;
    SELECT StatusName INTO v_status FROM RequestStatus WHERE StatusID = v_r.StatusID;

    DBMS_OUTPUT.PUT_LINE('===== คำขอ ' || p_requestid || ' =====');
    DBMS_OUTPUT.PUT_LINE('ผู้ขอ        : ' || v_name);
    DBMS_OUTPUT.PUT_LINE('ปลายทาง      : ' || v_r.Destination);
    DBMS_OUTPUT.PUT_LINE('วันที่เดินทาง  : ' || TO_CHAR(v_r.StartDate, 'DD/MM/YYYY') || ' - '
                         || TO_CHAR(v_r.EndDate, 'DD/MM/YYYY') || ' (' || v_r.TotalDays || ' วัน)');
    DBMS_OUTPUT.PUT_LINE('สถานะ        : ' || v_status);
    DBMS_OUTPUT.PUT_LINE('ยอดขอเบิก     : ' || v_r.RequestAmount);
    DBMS_OUTPUT.PUT_LINE('ยอดใช้จริง     : ' || NVL(TO_CHAR(v_r.ActualAmount), '-'));

    DBMS_OUTPUT.PUT_LINE('--- ผู้ร่วมเดินทาง ---');
    FOR c IN (SELECT e.FirstName || ' ' || e.LastName AS Name
                FROM TravelCompanion t JOIN Employee e ON e.EmpID = t.EmpID
               WHERE t.RequestID = p_requestid ORDER BY t.LineNo) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || c.Name);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--- การลงนาม ---');
    FOR s IN (SELECT a.LineNo, rs.StatusName, e.FirstName || ' ' || e.LastName AS Name,
                     a.SignDate, a.Result, a.RejectReason
                FROM ApprovalSignature a
                JOIN RequestStatus rs ON rs.StatusID = a.StatusID
                JOIN Employee e       ON e.EmpID     = a.EmpID
               WHERE a.RequestID = p_requestid ORDER BY a.LineNo) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || s.LineNo || '. ' || s.StatusName || ' : ' || s.Name || ' '
                             || TO_CHAR(s.SignDate, 'DD/MM/YYYY') || ' ' || s.Result
                             || CASE WHEN s.RejectReason IS NOT NULL THEN ' (' || s.RejectReason || ')' END);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--- การโอนเงิน ---');
    FOR t IN (SELECT tt.TypeName, te.Amount, te.TransferDate
                FROM TransferEvidence te JOIN TransferType tt ON tt.TypeID = te.TypeID
               WHERE te.RequestID = p_requestid ORDER BY te.TransferDate, te.EvidenceID) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || t.TypeName || ' ' || t.Amount || ' บาท '
                             || TO_CHAR(t.TransferDate, 'DD/MM/YYYY HH24:MI'));
    END LOOP;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบคำขอ: ' || p_requestid);
END;
/


-- ชุดทดสอบ (รันหลังสร้างตาราง ใส่ข้อมูล DML และ procedure ครบ)
-- SET SERVEROUTPUT ON
-- BEGIN
--     sp_create_request('TR007', 'E006', 'สำรวจหน้างานโครงการคอนโด', 'ถ.รามคำแหง กรุงเทพฯ',
--                       TRUNC(SYSDATE) + 3, TRUNC(SYSDATE) + 4, '3456789012', 'ปิยะนุช บุญเรือง',
--                       'ได้ปริมาณวัสดุสำหรับเสนอราคา');
--     sp_add_advance_item('TR007', 'ค่าน้ำมันรถ', 800, 1);
--     sp_add_advance_item('TR007', 'ค่าที่พัก', 1000, 1);
--     sp_add_companion('TR007', 'E005');
--     sp_sign_request('TR007', 'E001', 1);              -- หัวหน้าแผนก D01
--     sp_sign_request('TR007', 'E007', 1);              -- ฝ่ายบัญชี
--     sp_sign_request('TR007', 'E013', 1);              -- ผู้บริหาร -> RS04
--     sp_transfer_advance('TE006', 'TR007', 'ธนาคารกรุงไทย', 'KTB-TEST-01', 'https://slip.example.com/te006.jpg');
--     sp_add_travel_evidence('TR007', SYSDATE, 'ค่าน้ำมันรถ', 950, 'https://slip.example.com/tr007-1.jpg');
--     sp_add_travel_evidence('TR007', SYSDATE, 'ค่าที่พัก', 1000, 'https://slip.example.com/tr007-2.jpg');
--     sp_close_request('TE007', 'TR007', 'ธนาคารกรุงไทย', 'ปิยะนุช บุญเรือง', 'KTB-TEST-02', 'https://slip.example.com/te007.jpg');
--     sp_request_summary('TR007');
--     sp_change_manager('D01', 'E005', TRUNC(SYSDATE));
--     sp_resign_employee('E001', TRUNC(SYSDATE));
-- END;
-- /
-- ROLLBACK;
