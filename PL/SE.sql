-- SE : ระบบประกาศของหาย-ของพบ
-- SET SERVEROUTPUT ON


-- 1. Helper : ตรวจสอบ Admin

CREATE OR REPLACE FUNCTION fn_is_admin (
    p_userid IN VARCHAR2
) RETURN NUMBER AS
    v_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_cnt
      FROM Users u
      JOIN UserRole r ON r.RoleID = u.RoleID
     WHERE u.UserID = p_userid
       AND r.RoleName = 'Admin';
    RETURN v_cnt;
END;
/


-- 2. เปลี่ยนสถานะ (ประกาศพบ / ประกาศหาย / คำขอคืน)

-- ประกาศพบ
CREATE OR REPLACE PROCEDURE sp_change_found_status (
    p_postid   IN VARCHAR2,
    p_statusid IN VARCHAR2,
    p_userid   IN VARCHAR2
) AS
BEGIN
    UPDATE FoundPost SET StatusID = p_statusid WHERE FoundPostID = p_postid;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'ไม่พบประกาศพบ: ' || p_postid);
    END IF;
    DBMS_OUTPUT.PUT_LINE('ประกาศพบ ' || p_postid || ' -> ' || p_statusid);
END;
/

-- ประกาศหาของหาย
CREATE OR REPLACE PROCEDURE sp_change_lost_status (
    p_postid   IN VARCHAR2,
    p_statusid IN VARCHAR2,
    p_userid   IN VARCHAR2
) AS
BEGIN
    UPDATE LostPost SET StatusID = p_statusid WHERE LostPostID = p_postid;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'ไม่พบประกาศหาของหาย: ' || p_postid);
    END IF;
    DBMS_OUTPUT.PUT_LINE('ประกาศหาของหาย ' || p_postid || ' -> ' || p_statusid);
END;
/

-- คำขอคืน
CREATE OR REPLACE PROCEDURE sp_change_claim_status (
    p_requestid IN VARCHAR2,
    p_statusid  IN VARCHAR2,
    p_userid    IN VARCHAR2
) AS
BEGIN
    UPDATE ClaimRequest SET StatusID = p_statusid WHERE RequestID = p_requestid;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'ไม่พบคำขอคืน: ' || p_requestid);
    END IF;
    DBMS_OUTPUT.PUT_LINE('คำขอคืน ' || p_requestid || ' -> ' || p_statusid);
END;
/


-- 3. FoundPost : แอดมินโพสต์ประกาศพบ / ติดประเภท

CREATE OR REPLACE PROCEDURE sp_create_found_post (
    p_postid     IN VARCHAR2,
    p_title      IN VARCHAR2,
    p_itemname   IN VARCHAR2,
    p_findername IN VARCHAR2,
    p_finderphone IN VARCHAR2,
    p_finderemail IN VARCHAR2,
    p_finderaddr IN VARCHAR2,
    p_imageurl   IN VARCHAR2,
    p_location   IN VARCHAR2,
    p_founddate  IN DATE,
    p_adminid    IN VARCHAR2
) AS
BEGIN
    IF fn_is_admin(p_adminid) = 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'เฉพาะ Admin เท่านั้นที่โพสต์ประกาศพบได้: ' || p_adminid);
    END IF;

    INSERT INTO FoundPost (FoundPostID, Title, ItemName, FinderName, FinderPhone, FinderEmail,
                           FinderAddress, ImageURL, FoundLocation, StatusID, PostDate, FoundDate, UserID)
    VALUES (p_postid, p_title, p_itemname, p_findername, p_finderphone, p_finderemail,
            p_finderaddr, p_imageurl, p_location, 'PS01', TRUNC(SYSDATE), p_founddate, p_adminid);
    DBMS_OUTPUT.PUT_LINE('โพสต์ประกาศพบเรียบร้อย: ' || p_postid);
END;
/

CREATE OR REPLACE PROCEDURE sp_tag_found_post (
    p_postid     IN VARCHAR2,
    p_categoryid IN VARCHAR2
) AS
    v_line NUMBER;
BEGIN
    SELECT NVL(MAX(LineNo), 0) + 1 INTO v_line
      FROM FoundPostCategory WHERE FoundPostID = p_postid;
    INSERT INTO FoundPostCategory VALUES (p_postid, v_line, p_categoryid);
    DBMS_OUTPUT.PUT_LINE('ติดประเภท ' || p_categoryid || ' ให้ ' || p_postid);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('ประกาศ ' || p_postid || ' มีประเภท ' || p_categoryid || ' อยู่แล้ว');
END;
/


-- 4. LostPost : ผู้ใช้สร้างประกาศหาของหาย / ติดประเภท / ปิดประกาศ

CREATE OR REPLACE PROCEDURE sp_create_lost_post (
    p_postid IN VARCHAR2,
    p_title  IN VARCHAR2,
    p_userid IN VARCHAR2
) AS
BEGIN
    INSERT INTO LostPost VALUES (p_postid, p_title, TRUNC(SYSDATE), 'PS04', p_userid);
    DBMS_OUTPUT.PUT_LINE('สร้างประกาศหาของหายเรียบร้อย: ' || p_postid);
END;
/

CREATE OR REPLACE PROCEDURE sp_tag_lost_post (
    p_postid     IN VARCHAR2,
    p_categoryid IN VARCHAR2
) AS
    v_line NUMBER;
BEGIN
    SELECT NVL(MAX(LineNo), 0) + 1 INTO v_line
      FROM LostPostCategory WHERE LostPostID = p_postid;
    INSERT INTO LostPostCategory VALUES (p_postid, v_line, p_categoryid);
    DBMS_OUTPUT.PUT_LINE('ติดประเภท ' || p_categoryid || ' ให้ ' || p_postid);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('ประกาศ ' || p_postid || ' มีประเภท ' || p_categoryid || ' อยู่แล้ว');
END;
/

-- ปิดประกาศหาของหาย (เจ้าของประกาศ หรือ Admin เท่านั้น)
CREATE OR REPLACE PROCEDURE sp_close_lost_post (
    p_postid IN VARCHAR2,
    p_userid IN VARCHAR2,
    p_found  IN NUMBER     -- 1 = พบแล้ว, 0 = ปิดประกาศเฉยๆ
) AS
    v_owner LostPost.UserID%TYPE;
BEGIN
    SELECT UserID INTO v_owner FROM LostPost WHERE LostPostID = p_postid;
    IF v_owner <> p_userid AND fn_is_admin(p_userid) = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'ไม่มีสิทธิ์ปิดประกาศ: ' || p_postid);
    END IF;
    sp_change_lost_status(p_postid, CASE WHEN p_found = 1 THEN 'PS05' ELSE 'PS06' END, p_userid);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบประกาศหาของหาย: ' || p_postid);
END;
/


-- 5. ClaimRequest : เขียนคำขอคืน / อนุมัติ / ปฏิเสธ

-- เขียนคำขอคืน : ประกาศต้องยังไม่คืน/ปิด , ห้ามขอซ้ำในประกาศเดิมขณะคำขอเก่ายังรอพิจารณา
--               ประกาศที่ "รอเจ้าของ" จะถูกเปลี่ยนเป็น "กำลังตรวจสอบ"
CREATE OR REPLACE PROCEDURE sp_create_claim (
    p_requestid IN VARCHAR2,
    p_postid    IN VARCHAR2,
    p_userid    IN VARCHAR2,
    p_detail    IN VARCHAR2
) AS
    v_status  FoundPost.StatusID%TYPE;
    v_pending NUMBER;
BEGIN
    SELECT StatusID INTO v_status FROM FoundPost WHERE FoundPostID = p_postid FOR UPDATE;
    IF v_status IN ('PS03', 'PS06') THEN
        RAISE_APPLICATION_ERROR(-20020, 'ประกาศ ' || p_postid || ' คืนเจ้าของ/ปิดไปแล้ว');
    END IF;

    SELECT COUNT(*) INTO v_pending
      FROM ClaimRequest
     WHERE FoundPostID = p_postid AND UserID = p_userid AND StatusID = 'CS01';
    IF v_pending > 0 THEN
        RAISE_APPLICATION_ERROR(-20021, 'มีคำขอคืนที่รอพิจารณาของประกาศนี้อยู่แล้ว');
    END IF;

    INSERT INTO ClaimRequest VALUES (p_requestid, p_postid, p_userid, 'CS01', TRUNC(SYSDATE), p_detail);

    IF v_status = 'PS01' THEN
        sp_change_found_status(p_postid, 'PS02', p_userid);
    END IF;
    DBMS_OUTPUT.PUT_LINE('เขียนคำขอคืนเรียบร้อย: ' || p_requestid);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบประกาศพบ: ' || p_postid);
END;
/

-- อนุมัติคำขอคืน : คำขออื่นที่รอพิจารณาในประกาศเดียวกันถูกปฏิเสธอัตโนมัติ , ประกาศเป็น "คืนแล้ว"
CREATE OR REPLACE PROCEDURE sp_approve_claim (
    p_requestid IN VARCHAR2,
    p_adminid   IN VARCHAR2
) AS
    v_postid ClaimRequest.FoundPostID%TYPE;
    v_status ClaimRequest.StatusID%TYPE;
BEGIN
    IF fn_is_admin(p_adminid) = 0 THEN
        RAISE_APPLICATION_ERROR(-20030, 'เฉพาะ Admin เท่านั้นที่อนุมัติได้');
    END IF;

    SELECT FoundPostID, StatusID INTO v_postid, v_status
      FROM ClaimRequest WHERE RequestID = p_requestid;
    IF v_status <> 'CS01' THEN
        RAISE_APPLICATION_ERROR(-20031, 'คำขอ ' || p_requestid || ' ไม่ได้อยู่ในสถานะรอพิจารณา');
    END IF;

    sp_change_claim_status(p_requestid, 'CS02', p_adminid);

    FOR r IN (SELECT RequestID FROM ClaimRequest
               WHERE FoundPostID = v_postid AND StatusID = 'CS01') LOOP
        sp_change_claim_status(r.RequestID, 'CS03', p_adminid);
    END LOOP;

    sp_change_found_status(v_postid, 'PS03', p_adminid);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบคำขอคืน: ' || p_requestid);
END;
/

-- ปฏิเสธคำขอคืน : ถ้าไม่เหลือคำขอที่รอพิจารณา ประกาศกลับเป็น "รอเจ้าของ"
CREATE OR REPLACE PROCEDURE sp_reject_claim (
    p_requestid IN VARCHAR2,
    p_adminid   IN VARCHAR2
) AS
    v_postid  ClaimRequest.FoundPostID%TYPE;
    v_status  ClaimRequest.StatusID%TYPE;
    v_pending NUMBER;
BEGIN
    IF fn_is_admin(p_adminid) = 0 THEN
        RAISE_APPLICATION_ERROR(-20030, 'เฉพาะ Admin เท่านั้นที่ปฏิเสธได้');
    END IF;

    SELECT FoundPostID, StatusID INTO v_postid, v_status
      FROM ClaimRequest WHERE RequestID = p_requestid;
    IF v_status <> 'CS01' THEN
        RAISE_APPLICATION_ERROR(-20031, 'คำขอ ' || p_requestid || ' ไม่ได้อยู่ในสถานะรอพิจารณา');
    END IF;

    sp_change_claim_status(p_requestid, 'CS03', p_adminid);

    SELECT COUNT(*) INTO v_pending
      FROM ClaimRequest WHERE FoundPostID = v_postid AND StatusID = 'CS01';
    IF v_pending = 0 THEN
        sp_change_found_status(v_postid, 'PS01', p_adminid);
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบคำขอคืน: ' || p_requestid);
END;
/


-- 6. Report : จับคู่ประกาศหาย-ประกาศพบ

-- หาประกาศพบที่น่าจะตรงกับประกาศหาของหาย (ประเภทตรงกัน + ยังไม่คืน + พบหลังวันประกาศหาไม่เกิน 7 วันก่อน)
CREATE OR REPLACE PROCEDURE sp_match_lost_post (
    p_lostid IN VARCHAR2
) AS
    v_cnt NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===== ประกาศพบที่อาจตรงกับ ' || p_lostid || ' =====');
    FOR r IN (
        SELECT f.FoundPostID, f.Title, f.FoundLocation, s.StatusName,
               COUNT(DISTINCT fc.CategoryID) AS MatchCat
          FROM LostPost l
          JOIN LostPostCategory lc  ON lc.LostPostID  = l.LostPostID
          JOIN FoundPostCategory fc ON fc.CategoryID  = lc.CategoryID
          JOIN FoundPost f          ON f.FoundPostID  = fc.FoundPostID
          JOIN PostStatus s         ON s.StatusID     = f.StatusID
         WHERE l.LostPostID = p_lostid
           AND f.StatusID IN ('PS01', 'PS02')
           AND f.FoundDate >= l.PostDate - 7
         GROUP BY f.FoundPostID, f.Title, f.FoundLocation, s.StatusName
         ORDER BY MatchCat DESC, f.FoundPostID
    ) LOOP
        v_cnt := v_cnt + 1;
        DBMS_OUTPUT.PUT_LINE(r.FoundPostID || '  ' || r.Title || '  [' || r.FoundLocation || ']  '
                             || r.StatusName || '  ประเภทตรง ' || r.MatchCat);
    END LOOP;
    IF v_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ไม่พบประกาศที่ตรงกัน');
    END IF;
END;
/


-- ชุดทดสอบ (รันหลังสร้างตาราง ใส่ข้อมูล DML และ procedure ครบ)
-- SET SERVEROUTPUT ON
-- BEGIN
--     sp_create_found_post('FP009', 'พบโน้ตบุ๊กสีเทา', 'Asus Vivobook', 'ธีระ ใจดี', '0991234567',
--                          'teera.j@kmitl.ac.th', 'ภาควิชาเคมี', 'https://img.example.com/fp009.jpg',
--                          'ห้องสมุดคณะวิทยาศาสตร์ ชั้น 1', TRUNC(SYSDATE), 'U001');
--     sp_tag_found_post('FP009', 'CT01');
--     sp_match_lost_post('LP003');                      -- ควรเจอ FP009
--     sp_create_claim('RQ008', 'FP009', 'U005', 'โน้ตบุ๊กมีสติกเกอร์ชื่อกมลชนก');
--     sp_create_claim('RQ009', 'FP009', 'U006', 'น่าจะเป็นของผม');
--     sp_approve_claim('RQ008', 'U001');                -- RQ009 ถูกปฏิเสธอัตโนมัติ
--     sp_close_lost_post('LP003', 'U005', 1);
--     sp_reject_claim('RQ002', 'U001');                 -- FP002 ไม่เหลือคำขอรอพิจารณา -> กลับเป็นรอเจ้าของ
-- END;
-- /
-- ROLLBACK;
