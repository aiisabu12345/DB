-- SE : ระบบประกาศของหาย-ของพบ : คำสั่ง SQL ทดลอง join แบบซับซ้อน


-- 1. รายงานประกาศพบแบบเต็ม
--    ประกาศ + แอดมินผู้โพสต์ + ประเภททั้งหมด + จำนวนคำขอแยกตามสถานะ
--    + ผู้ที่ได้รับของคืน + จำนวนครั้งที่เปลี่ยนสถานะ + ใช้เวลากี่วันจนคืนของ

WITH cat AS (
    SELECT fc.FoundPostID,
           LISTAGG(c.CategoryName, ', ') WITHIN GROUP (ORDER BY fc.LineNo) AS Categories
      FROM FoundPostCategory fc
      JOIN Category c ON c.CategoryID = fc.CategoryID
     GROUP BY fc.FoundPostID
),
claim AS (
    SELECT cr.FoundPostID,
           COUNT(*)                                               AS TotalClaim,
           SUM(CASE WHEN cs.StatusName = 'รอพิจารณา' THEN 1 ELSE 0 END) AS Pending,
           SUM(CASE WHEN cs.StatusName = 'อนุมัติ'   THEN 1 ELSE 0 END) AS Approved,
           SUM(CASE WHEN cs.StatusName = 'ปฏิเสธ'    THEN 1 ELSE 0 END) AS Rejected,
           MAX(CASE WHEN cs.StatusName = 'อนุมัติ'
                    THEN u.FirstName || ' ' || u.LastName END)     AS ReturnedTo
      FROM ClaimRequest cr
      JOIN ClaimStatus cs ON cs.StatusID = cr.StatusID
      JOIN Users u        ON u.UserID    = cr.UserID
     GROUP BY cr.FoundPostID
),
lg AS (
    SELECT l.FoundPostID,
           COUNT(*)                                                    AS StatusChanges,
           MIN(l.ChangeDate)                                           AS FirstLog,
           MIN(CASE WHEN ps.StatusName = 'คืนแล้ว' THEN l.ChangeDate END) AS ReturnedAt
      FROM FoundPostStatusLog l
      JOIN PostStatus ps ON ps.StatusID = l.StatusID
     GROUP BY l.FoundPostID
)
SELECT f.FoundPostID                          AS Post_ID,
       f.Title                                AS Title,
       f.FoundLocation                        AS Location,
       a.FirstName || ' ' || a.LastName       AS Posted_By,
       r.RoleName                             AS Poster_Role,
       NVL(cat.Categories, '-')               AS Categories,
       ps.StatusName                          AS Status,
       NVL(claim.TotalClaim, 0)               AS Claims,
       NVL(claim.Pending, 0)                  AS Pending,
       NVL(claim.Approved, 0)                 AS Approved,
       NVL(claim.Rejected, 0)                 AS Rejected,
       NVL(claim.ReturnedTo, '-')             AS Returned_To,
       lg.StatusChanges                       AS Status_Changes,
       ROUND(lg.ReturnedAt - lg.FirstLog, 2)  AS Days_To_Return
  FROM FoundPost f
  JOIN Users a       ON a.UserID    = f.UserID
  JOIN UserRole r    ON r.RoleID    = a.RoleID
  JOIN PostStatus ps ON ps.StatusID = f.StatusID
  LEFT JOIN cat      ON cat.FoundPostID   = f.FoundPostID
  LEFT JOIN claim    ON claim.FoundPostID = f.FoundPostID
  LEFT JOIN lg       ON lg.FoundPostID    = f.FoundPostID
 ORDER BY f.PostDate, f.FoundPostID;


-- 2. จับคู่ประกาศหาของหาย กับ ประกาศพบ ที่อาจเป็นของชิ้นเดียวกัน
--    เงื่อนไข : ประเภทตรงกันอย่างน้อย 1 , พบไม่เกิน 7 วันก่อนประกาศหา , จัดอันดับต่อประกาศหา
--    และบอกว่าเจ้าของประกาศหาได้เขียนคำขอคืนประกาศพบนั้นแล้วหรือยัง

SELECT *
  FROM (
    SELECT lp.LostPostID                              AS Lost_ID,
           lp.Title                                   AS Lost_Title,
           ou.FirstName || ' ' || ou.LastName         AS Owner,
           lps.StatusName                             AS Lost_Status,
           fp.FoundPostID                             AS Found_ID,
           fp.Title                                   AS Found_Title,
           fps.StatusName                             AS Found_Status,
           COUNT(DISTINCT lc.CategoryID)              AS Match_Cat,
           LISTAGG(DISTINCT c.CategoryName, ', ')
               WITHIN GROUP (ORDER BY c.CategoryName) AS Match_Names,
           fp.FoundDate - lp.PostDate                 AS Day_Diff,
           CASE WHEN MAX(cr.RequestID) IS NOT NULL
                THEN 'เขียนคำขอแล้ว (' || MAX(crs.StatusName) || ')'
                ELSE N'ยังไม่ได้ขอ' END                  AS Claim_Status,
           DENSE_RANK() OVER (PARTITION BY lp.LostPostID
                              ORDER BY COUNT(DISTINCT lc.CategoryID) DESC,
                                       ABS(fp.FoundDate - lp.PostDate)) AS Rank_No
      FROM LostPost lp
      JOIN Users ou              ON ou.UserID      = lp.UserID
      JOIN PostStatus lps        ON lps.StatusID   = lp.StatusID
      JOIN LostPostCategory lc   ON lc.LostPostID  = lp.LostPostID
      JOIN FoundPostCategory fc  ON fc.CategoryID  = lc.CategoryID
      JOIN Category c            ON c.CategoryID   = lc.CategoryID
      JOIN FoundPost fp          ON fp.FoundPostID = fc.FoundPostID
      JOIN PostStatus fps        ON fps.StatusID   = fp.StatusID
      LEFT JOIN ClaimRequest cr  ON cr.FoundPostID = fp.FoundPostID
                                AND cr.UserID      = lp.UserID
      LEFT JOIN ClaimStatus crs  ON crs.StatusID   = cr.StatusID
     WHERE fp.FoundDate >= lp.PostDate - 7
     GROUP BY lp.LostPostID, lp.Title, ou.FirstName, ou.LastName, lps.StatusName,
              fp.FoundPostID, fp.Title, fps.StatusName, fp.FoundDate, lp.PostDate
  )
 ORDER BY Lost_ID, Rank_No;


-- 3. Timeline สถานะของคำขอคืน : แต่ละขั้นอยู่นานเท่าไหร่ ใครเปลี่ยน (ผู้ใช้/แอดมิน)
--    ใช้ LEAD หาเวลาเปลี่ยนครั้งถัดไป และ LAG หาสถานะก่อนหน้า

SELECT l.RequestID                                             AS Request_ID,
       fp.Title                                                AS Found_Post,
       req.FirstName || ' ' || req.LastName                    AS Claimant,
       l.LineNo                                                AS Step,
       LAG(cs.StatusName) OVER (PARTITION BY l.RequestID ORDER BY l.LineNo) AS From_Status,
       cs.StatusName                                           AS To_Status,
       TO_CHAR(l.ChangeDate, 'DD/MM/YYYY HH24:MI')             AS Changed_At,
       cu.FirstName || ' ' || cu.LastName                      AS Changed_By,
       ur.RoleName                                             AS Changed_By_Role,
       ROUND((LEAD(l.ChangeDate) OVER (PARTITION BY l.RequestID ORDER BY l.LineNo)
              - l.ChangeDate) * 24, 1)                         AS Hours_In_Status
  FROM ClaimRequestStatusLog l
  JOIN ClaimStatus cs   ON cs.StatusID   = l.StatusID
  JOIN Users cu         ON cu.UserID     = l.UserID
  JOIN UserRole ur      ON ur.RoleID     = cu.RoleID
  JOIN ClaimRequest cr  ON cr.RequestID  = l.RequestID
  JOIN Users req        ON req.UserID    = cr.UserID
  JOIN FoundPost fp     ON fp.FoundPostID = cr.FoundPostID
 ORDER BY l.RequestID, l.LineNo;


-- 4. สรุปกิจกรรมของผู้ใช้ทุกคน (ผู้ใช้ทั่วไป + แอดมิน)
--    ประกาศหา / คำขอคืน / อัตราอนุมัติ / ประกาศพบที่โพสต์ / จำนวนครั้งที่เปลี่ยนสถานะใน log ทั้ง 3 ตาราง

WITH all_log AS (
    SELECT UserID FROM FoundPostStatusLog
    UNION ALL
    SELECT UserID FROM LostPostStatusLog
    UNION ALL
    SELECT UserID FROM ClaimRequestStatusLog
)
SELECT u.UserID                                         AS User_ID,
       u.FirstName || ' ' || u.LastName                 AS Name,
       r.RoleName                                       AS Role,
       NVL(lp.Cnt, 0)                                   AS Lost_Posts,
       NVL(fp.Cnt, 0)                                   AS Found_Posts,
       NVL(cr.Total, 0)                                 AS Claims,
       NVL(cr.Approved, 0)                              AS Claims_Approved,
       CASE WHEN NVL(cr.Total, 0) = 0 THEN NULL
            ELSE ROUND(cr.Approved / cr.Total * 100, 1) END AS Approve_Rate_Pct,
       NVL(lg.Cnt, 0)                                   AS Status_Actions
  FROM Users u
  JOIN UserRole r ON r.RoleID = u.RoleID
  LEFT JOIN (SELECT UserID, COUNT(*) Cnt FROM LostPost  GROUP BY UserID) lp ON lp.UserID = u.UserID
  LEFT JOIN (SELECT UserID, COUNT(*) Cnt FROM FoundPost GROUP BY UserID) fp ON fp.UserID = u.UserID
  LEFT JOIN (SELECT c.UserID, COUNT(*) Total,
                    SUM(CASE WHEN s.StatusName = 'อนุมัติ' THEN 1 ELSE 0 END) Approved
               FROM ClaimRequest c JOIN ClaimStatus s ON s.StatusID = c.StatusID
              GROUP BY c.UserID) cr ON cr.UserID = u.UserID
  LEFT JOIN (SELECT UserID, COUNT(*) Cnt FROM all_log GROUP BY UserID) lg ON lg.UserID = u.UserID
 ORDER BY r.RoleName, u.UserID;


-- 5. สถิติตามประเภทสิ่งของ : พบกี่ชิ้น หาย(ประกาศหา)กี่ชิ้น คืนแล้วกี่ชิ้น อัตราคืน
--    และเวลาเฉลี่ยตั้งแต่โพสต์จนคืน (ชั่วโมง) จาก log

WITH returned AS (
    SELECT l.FoundPostID,
           (MAX(CASE WHEN ps.StatusName = 'คืนแล้ว' THEN l.ChangeDate END) - MIN(l.ChangeDate)) * 24 AS Hours
      FROM FoundPostStatusLog l
      JOIN PostStatus ps ON ps.StatusID = l.StatusID
     GROUP BY l.FoundPostID
),
found_side AS (
    SELECT fc.CategoryID,
           COUNT(*)                                                   AS Found_Posts,
           SUM(CASE WHEN fps.StatusName = 'คืนแล้ว' THEN 1 ELSE 0 END)  AS Returned,
           AVG(rt.Hours)                                              AS Avg_Hours
      FROM FoundPostCategory fc
      JOIN FoundPost f     ON f.FoundPostID  = fc.FoundPostID
      JOIN PostStatus fps  ON fps.StatusID   = f.StatusID
      LEFT JOIN returned rt ON rt.FoundPostID = fc.FoundPostID
     GROUP BY fc.CategoryID
),
lost_side AS (
    SELECT lc.CategoryID,
           COUNT(*)                                                   AS Lost_Posts,
           SUM(CASE WHEN lps.StatusName = 'พบแล้ว' THEN 1 ELSE 0 END)   AS Lost_Found
      FROM LostPostCategory lc
      JOIN LostPost l      ON l.LostPostID = lc.LostPostID
      JOIN PostStatus lps  ON lps.StatusID = l.StatusID
     GROUP BY lc.CategoryID
)
SELECT c.CategoryID                                              AS Category_ID,
       c.CategoryName                                            AS Category,
       NVL(fs.Found_Posts, 0)                                    AS Found_Posts,
       NVL(fs.Returned, 0)                                       AS Returned,
       ROUND(fs.Returned / NULLIF(fs.Found_Posts, 0) * 100, 1)   AS Return_Rate_Pct,
       ROUND(fs.Avg_Hours, 1)                                    AS Avg_Hours_To_Return,
       NVL(ls.Lost_Posts, 0)                                     AS Lost_Posts,
       NVL(ls.Lost_Found, 0)                                     AS Lost_Found
  FROM Category c
  LEFT JOIN found_side fs ON fs.CategoryID = c.CategoryID
  LEFT JOIN lost_side ls  ON ls.CategoryID = c.CategoryID
 ORDER BY NVL(fs.Found_Posts, 0) + NVL(ls.Lost_Posts, 0) DESC, c.CategoryID;


-- 6. ประกาศพบที่มีหลายคนแย่งขอคืน (self join ClaimRequest)
--    แสดงคู่ผู้ขอที่ขอประกาศเดียวกัน ใครขอก่อน และผลของแต่ละคน

SELECT c1.FoundPostID                           AS Post_ID,
       f.Title                                  AS Title,
       u1.FirstName || ' ' || u1.LastName       AS Claimant_1,
       s1.StatusName                            AS Result_1,
       u2.FirstName || ' ' || u2.LastName       AS Claimant_2,
       s2.StatusName                            AS Result_2,
       CASE WHEN l1.ChangeDate < l2.ChangeDate THEN u1.FirstName
            ELSE u2.FirstName END               AS First_To_Claim,
       ROUND(ABS(l2.ChangeDate - l1.ChangeDate) * 24 * 60) AS Minutes_Apart
  FROM ClaimRequest c1
  JOIN ClaimRequest c2           ON c2.FoundPostID = c1.FoundPostID
                                AND c2.RequestID   > c1.RequestID
  JOIN FoundPost f               ON f.FoundPostID  = c1.FoundPostID
  JOIN Users u1                  ON u1.UserID      = c1.UserID
  JOIN Users u2                  ON u2.UserID      = c2.UserID
  JOIN ClaimStatus s1            ON s1.StatusID    = c1.StatusID
  JOIN ClaimStatus s2            ON s2.StatusID    = c2.StatusID
  JOIN ClaimRequestStatusLog l1  ON l1.RequestID   = c1.RequestID AND l1.LineNo = 1
  JOIN ClaimRequestStatusLog l2  ON l2.RequestID   = c2.RequestID AND l2.LineNo = 1
 ORDER BY c1.FoundPostID;


-- 7. ตรวจความถูกต้อง : สถานะปัจจุบันใน main table ตรงกับ log ล่าสุดหรือไม่ (ทั้ง 3 ตาราง)

SELECT 'FoundPost' AS Table_Name, f.FoundPostID AS Record_ID, f.StatusID AS Current_Status, l.StatusID AS Last_Log,
       CASE WHEN f.StatusID = l.StatusID THEN 'OK' ELSE 'MISMATCH' END AS Check_Result
  FROM FoundPost f
  LEFT JOIN FoundPostStatusLog l
         ON l.FoundPostID = f.FoundPostID
        AND l.LineNo = (SELECT MAX(x.LineNo) FROM FoundPostStatusLog x WHERE x.FoundPostID = f.FoundPostID)
UNION ALL
SELECT 'LostPost', p.LostPostID, p.StatusID, l.StatusID,
       CASE WHEN p.StatusID = l.StatusID THEN 'OK' ELSE 'MISMATCH' END
  FROM LostPost p
  LEFT JOIN LostPostStatusLog l
         ON l.LostPostID = p.LostPostID
        AND l.LineNo = (SELECT MAX(x.LineNo) FROM LostPostStatusLog x WHERE x.LostPostID = p.LostPostID)
UNION ALL
SELECT 'ClaimRequest', c.RequestID, c.StatusID, l.StatusID,
       CASE WHEN c.StatusID = l.StatusID THEN 'OK' ELSE 'MISMATCH' END
  FROM ClaimRequest c
  LEFT JOIN ClaimRequestStatusLog l
         ON l.RequestID = c.RequestID
        AND l.LineNo = (SELECT MAX(x.LineNo) FROM ClaimRequestStatusLog x WHERE x.RequestID = c.RequestID)
 ORDER BY 1, 2;
