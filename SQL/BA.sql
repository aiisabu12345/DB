-- BA : ระบบขออนุญาตเดินทางและเบิกค่าใช้จ่าย : คำสั่ง SQL ทดลอง join แบบซับซ้อน


-- 1. รายงานคำขออนุมัติการเดินทางแบบเต็ม
--    ผู้ขอ + แผนก + หัวหน้าแผนก (join Employee ซ้ำ) + ผู้ร่วมเดินทาง + ยอดประมาณ/ยอดจริง
--    + ยอดโอนแยกตามประเภท + ตรวจว่ายอดเงินปิดได้ลงตัวหรือไม่

WITH comp AS (
    SELECT t.RequestID,
           COUNT(*) AS Companions,
           LISTAGG(e.FirstName, ', ') WITHIN GROUP (ORDER BY t.LineNo) AS Companion_Names
      FROM TravelCompanion t
      JOIN Employee e ON e.EmpID = t.EmpID
     GROUP BY t.RequestID
),
est AS (
    SELECT RequestID, SUM(UnitPrice * Quantity) AS Estimated, COUNT(*) AS Items
      FROM AdvanceExpenseItem GROUP BY RequestID
),
act AS (
    SELECT RequestID, SUM(Amount) AS Actual, COUNT(*) AS Slips
      FROM TravelEvidence GROUP BY RequestID
),
tf AS (
    SELECT te.RequestID,
           SUM(CASE WHEN tt.TypeName = 'โอนเงินสำรองจ่าย'  THEN te.Amount ELSE 0 END) AS Advance,
           SUM(CASE WHEN tt.TypeName = 'คืนเงินที่ใช้เหลือ' THEN te.Amount ELSE 0 END) AS Refund,
           SUM(CASE WHEN tt.TypeName = 'เบิกเงินที่ใช้เกิน' THEN te.Amount ELSE 0 END) AS Extra
      FROM TransferEvidence te
      JOIN TransferType tt ON tt.TypeID = te.TypeID
     GROUP BY te.RequestID
)
SELECT r.RequestID                              AS Request_ID,
       e.FirstName || ' ' || e.LastName         AS Requester,
       d.DeptName                               AS Department,
       m.FirstName || ' ' || m.LastName         AS Dept_Manager,
       r.Destination                            AS Destination,
       r.TotalDays                              AS Days,
       (1 + NVL(comp.Companions, 0))            AS Travellers,
       NVL(comp.Companion_Names, '-')           AS Companions,
       rs.StatusName                            AS Status,
       NVL(est.Estimated, 0)                    AS Estimated,
       act.Actual                               AS Actual,
       NVL(tf.Advance, 0)                       AS Advance_Paid,
       NVL(tf.Refund, 0)                        AS Refund,
       NVL(tf.Extra, 0)                         AS Extra_Paid,
       NVL(tf.Advance, 0) - NVL(tf.Refund, 0) + NVL(tf.Extra, 0) AS Net_Paid,
       CASE
           WHEN rs.StatusName <> 'ปิดยอดแล้ว' THEN 'ยังไม่ปิดยอด'
           WHEN NVL(tf.Advance, 0) - NVL(tf.Refund, 0) + NVL(tf.Extra, 0) = act.Actual THEN 'ลงตัว'
           ELSE 'ยอดไม่ตรง'
       END                                      AS Balance_Check
  FROM TravelRequest r
  JOIN Employee e       ON e.EmpID      = r.EmpID
  JOIN Department d     ON d.DeptID     = e.DeptID
  LEFT JOIN Employee m  ON m.EmpID      = d.ManagerID
  JOIN RequestStatus rs ON rs.StatusID  = r.StatusID
  LEFT JOIN comp        ON comp.RequestID = r.RequestID
  LEFT JOIN est         ON est.RequestID  = r.RequestID
  LEFT JOIN act         ON act.RequestID  = r.RequestID
  LEFT JOIN tf          ON tf.RequestID   = r.RequestID
 ORDER BY r.WriteDate, r.RequestID;


-- 2. สายการลงนามของแต่ละคำขอ
--    ลำดับ + ขั้นตอน (จาก RequestStatus) + ผู้ลงนาม + แผนกผู้ลงนาม + ใช้เวลากี่วันจากขั้นก่อน (LAG)

SELECT a.RequestID                                       AS Request_ID,
       req.FirstName || ' ' || req.LastName              AS Requester,
       a.LineNo                                          AS Sign_No,
       rs.FlowOrder                                      AS Flow_Order,
       rs.StatusName                                     AS Step,
       s.FirstName || ' ' || s.LastName                  AS Signer,
       sd.DeptName                                       AS Signer_Dept,
       a.SignDate                                        AS Sign_Date,
       a.SignDate - LAG(a.SignDate, 1, r.WriteDate)
                    OVER (PARTITION BY a.RequestID ORDER BY a.LineNo) AS Days_From_Prev,
       a.Result                                          AS Result,
       NVL(a.RejectReason, '-')                          AS Reject_Reason
  FROM ApprovalSignature a
  JOIN TravelRequest r       ON r.RequestID  = a.RequestID
  JOIN Employee req          ON req.EmpID    = r.EmpID
  JOIN RequestStatus rs      ON rs.StatusID  = a.StatusID
  JOIN Employee s            ON s.EmpID      = a.EmpID
  JOIN Department sd         ON sd.DeptID    = s.DeptID
 ORDER BY a.RequestID, a.LineNo;


-- 3. กล่องงานรออนุมัติ : คำขอที่ค้างอยู่ในขั้นลงนาม ใครลงนามได้ตอนนี้บ้าง
--    ขั้นแรกของ flow ต้องเป็นหัวหน้าแผนกของผู้ขอเท่านั้น , ไม่รวมคนลาออก และไม่ให้ลงนามคำขอตัวเอง
--    + ค้างมาแล้วกี่วัน (นับจากลงนามล่าสุด หรือวันเขียนคำขอ)

SELECT r.RequestID                                AS Request_ID,
       req.FirstName || ' ' || req.LastName       AS Requester,
       d.DeptName                                 AS Requester_Dept,
       rs.StatusName                              AS Waiting_Step,
       ap.EmpID                                   AS Approver_ID,
       ap.FirstName || ' ' || ap.LastName         AS Approver,
       apd.DeptName                               AS Approver_Dept,
       TRUNC(SYSDATE) - NVL((SELECT MAX(x.SignDate) FROM ApprovalSignature x
                              WHERE x.RequestID = r.RequestID), r.WriteDate) AS Days_Waiting
  FROM TravelRequest r
  JOIN Employee req      ON req.EmpID    = r.EmpID
  JOIN Department d      ON d.DeptID     = req.DeptID
  JOIN RequestStatus rs  ON rs.StatusID  = r.StatusID
  JOIN StatusApprover sa ON sa.StatusID  = r.StatusID
  JOIN Employee ap       ON ap.EmpID     = sa.EmpID
  JOIN Department apd    ON apd.DeptID   = ap.DeptID
 WHERE ap.ResignDate IS NULL
   AND ap.EmpID <> r.EmpID
   AND (rs.FlowOrder <> (SELECT MIN(FlowOrder) FROM RequestStatus)
        OR ap.EmpID = d.ManagerID)
 ORDER BY Days_Waiting DESC, r.RequestID, sa.LineNo;


-- 4. สถิติการเดินทางของพนักงาน (นับทั้งตอนเป็นผู้ขอ และผู้ร่วมเดินทาง)
--    รวมตามแผนกด้วย ROLLUP (แถว Subtotal ต่อแผนก และ Grand Total)

WITH trips AS (
    SELECT r.EmpID, r.RequestID, 'ผู้ขอ' AS Role_In_Trip, r.TotalDays, r.StatusID
      FROM TravelRequest r
    UNION ALL
    SELECT t.EmpID, t.RequestID, 'ผู้ร่วมเดินทาง', r.TotalDays, r.StatusID
      FROM TravelCompanion t
      JOIN TravelRequest r ON r.RequestID = t.RequestID
)
SELECT CASE WHEN GROUPING(d.DeptName) = 1 THEN N'== รวมทั้งหมด =='
            ELSE d.DeptName END                               AS Department,
       CASE WHEN GROUPING(e.EmpID) = 1 AND GROUPING(d.DeptName) = 0 THEN N'-- รวมแผนก --'
            ELSE MAX(e.FirstName || ' ' || e.LastName) END    AS Employee,
       COUNT(tr.RequestID)                                    AS Trips,
       SUM(CASE WHEN tr.Role_In_Trip = 'ผู้ขอ' THEN 1 ELSE 0 END) AS As_Requester,
       SUM(CASE WHEN tr.Role_In_Trip = 'ผู้ร่วมเดินทาง' THEN 1 ELSE 0 END) AS As_Companion,
       NVL(SUM(CASE WHEN rs.StatusName <> 'ไม่อนุมัติ' THEN tr.TotalDays END), 0) AS Approved_Days,
       MAX(CASE WHEN e.ResignDate IS NOT NULL THEN 'ลาออก' ELSE NULL END) AS Note
  FROM Employee e
  JOIN Department d          ON d.DeptID    = e.DeptID
  LEFT JOIN trips tr         ON tr.EmpID    = e.EmpID
  LEFT JOIN RequestStatus rs ON rs.StatusID = tr.StatusID
 GROUP BY ROLLUP (d.DeptName, e.EmpID)
 ORDER BY GROUPING(d.DeptName), d.DeptName, GROUPING(e.EmpID), e.EmpID;


-- 5. เปรียบเทียบรายการค่าใช้จ่ายล่วงหน้า กับ หลักฐานการเดินทาง แยกรายการ (FULL OUTER JOIN)
--    จับคู่ตามชื่อรายการ (หลักฐานอาจเขียนต่อท้าย เช่น "ค่าที่พัก 2 คืน")
--    เฉพาะคำขอที่มีหลักฐานแล้ว

WITH est AS (
    SELECT RequestID, ItemName, UnitPrice * Quantity AS Estimated
      FROM AdvanceExpenseItem
),
act AS (
    SELECT RequestID, ItemName, Amount
      FROM TravelEvidence
)
SELECT NVL(est.RequestID, act.RequestID)          AS Request_ID,
       NVL(est.ItemName, act.ItemName)            AS Item,
       est.Estimated                              AS Estimated,
       act.Amount                                 AS Actual,
       NVL(act.Amount, 0) - NVL(est.Estimated, 0) AS Diff,
       CASE
           WHEN est.ItemName IS NULL THEN 'ไม่ได้ขอไว้ล่วงหน้า'
           WHEN act.ItemName IS NULL THEN 'ไม่ได้ใช้ / ไม่มีหลักฐาน'
           WHEN act.Amount > est.Estimated THEN 'ใช้เกิน'
           WHEN act.Amount < est.Estimated THEN 'ใช้ไม่หมด'
           ELSE 'พอดี'
       END                                        AS Result
  FROM est
  FULL OUTER JOIN act
    ON act.RequestID = est.RequestID
   AND act.ItemName LIKE est.ItemName || '%'
 WHERE NVL(est.RequestID, act.RequestID) IN (SELECT RequestID FROM TravelEvidence)
 ORDER BY 1, 2;


-- 6. Funnel ของ flow สถานะ : แต่ละขั้นมีคำขอค้างอยู่กี่ฉบับ และผ่านขั้นนี้มาแล้วกี่ฉบับ
--    (non-equi join ด้วย FlowOrder <=) + รายชื่อผู้มีสิทธิ์ลงนามในขั้นนั้น

SELECT rs.FlowOrder                                         AS Flow_Order,
       rs.StatusID                                          AS Status_ID,
       rs.StatusName                                        AS Status,
       (SELECT COUNT(*) FROM TravelRequest r
         WHERE r.StatusID = rs.StatusID)                    AS Currently_Here,
       COUNT(DISTINCT r2.RequestID)                         AS Reached_Or_Passed,
       (SELECT LISTAGG(e.FirstName, ', ') WITHIN GROUP (ORDER BY sa.LineNo)
          FROM StatusApprover sa JOIN Employee e ON e.EmpID = sa.EmpID
         WHERE sa.StatusID = rs.StatusID)                   AS Approvers
  FROM RequestStatus rs
  LEFT JOIN (TravelRequest r2
             JOIN RequestStatus cur ON cur.StatusID = r2.StatusID)
         ON cur.FlowOrder >= rs.FlowOrder
 GROUP BY rs.FlowOrder, rs.StatusID, rs.StatusName
 ORDER BY NVL(rs.FlowOrder, 999);
