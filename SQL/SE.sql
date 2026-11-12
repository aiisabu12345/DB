-- SE : ระบบประกาศของหาย-ของพบ : คำสั่ง SQL ทดลอง join แบบซับซ้อน


-- 1. รายงานประกาศพบแบบเต็ม
--    ประกาศ + แอดมินผู้โพสต์ + ประเภททั้งหมด + จำนวนคำขอแยกตามสถานะ
--    + ผู้ที่ได้รับของคืน

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
       NVL(claim.ReturnedTo, '-')             AS Returned_To
  FROM FoundPost f
  JOIN Users a       ON a.UserID    = f.UserID
  JOIN UserRole r    ON r.RoleID    = a.RoleID
  JOIN PostStatus ps ON ps.StatusID = f.StatusID
  LEFT JOIN cat      ON cat.FoundPostID   = f.FoundPostID
  LEFT JOIN claim    ON claim.FoundPostID = f.FoundPostID
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


-- 3. สรุปกิจกรรมของผู้ใช้ทุกคน (ผู้ใช้ทั่วไป + แอดมิน)
--    ประกาศหา / คำขอคืน / อัตราอนุมัติ / ประกาศพบที่โพสต์

SELECT u.UserID                                         AS User_ID,
       u.FirstName || ' ' || u.LastName                 AS Name,
       r.RoleName                                       AS Role,
       NVL(lp.Cnt, 0)                                   AS Lost_Posts,
       NVL(fp.Cnt, 0)                                   AS Found_Posts,
       NVL(cr.Total, 0)                                 AS Claims,
       NVL(cr.Approved, 0)                              AS Claims_Approved,
       CASE WHEN NVL(cr.Total, 0) = 0 THEN NULL
            ELSE ROUND(cr.Approved / cr.Total * 100, 1) END AS Approve_Rate_Pct
  FROM Users u
  JOIN UserRole r ON r.RoleID = u.RoleID
  LEFT JOIN (SELECT UserID, COUNT(*) Cnt FROM LostPost  GROUP BY UserID) lp ON lp.UserID = u.UserID
  LEFT JOIN (SELECT UserID, COUNT(*) Cnt FROM FoundPost GROUP BY UserID) fp ON fp.UserID = u.UserID
  LEFT JOIN (SELECT c.UserID, COUNT(*) Total,
                    SUM(CASE WHEN s.StatusName = 'อนุมัติ' THEN 1 ELSE 0 END) Approved
               FROM ClaimRequest c JOIN ClaimStatus s ON s.StatusID = c.StatusID
              GROUP BY c.UserID) cr ON cr.UserID = u.UserID
 ORDER BY r.RoleName, u.UserID;


-- 4. สถิติตามประเภทสิ่งของ : พบกี่ชิ้น หาย(ประกาศหา)กี่ชิ้น คืนแล้วกี่ชิ้น อัตราคืน

WITH found_side AS (
    SELECT fc.CategoryID,
           COUNT(*)                                                   AS Found_Posts,
           SUM(CASE WHEN fps.StatusName = 'คืนแล้ว' THEN 1 ELSE 0 END)  AS Returned
      FROM FoundPostCategory fc
      JOIN FoundPost f     ON f.FoundPostID  = fc.FoundPostID
      JOIN PostStatus fps  ON fps.StatusID   = f.StatusID
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
       NVL(ls.Lost_Posts, 0)                                     AS Lost_Posts,
       NVL(ls.Lost_Found, 0)                                     AS Lost_Found
  FROM Category c
  LEFT JOIN found_side fs ON fs.CategoryID = c.CategoryID
  LEFT JOIN lost_side ls  ON ls.CategoryID = c.CategoryID
 ORDER BY NVL(fs.Found_Posts, 0) + NVL(ls.Lost_Posts, 0) DESC, c.CategoryID;


-- 5. ประกาศพบที่มีหลายคนแย่งขอคืน (self join ClaimRequest)
--    แสดงคู่ผู้ขอที่ขอประกาศเดียวกัน ใครขอก่อน และผลของแต่ละคน

SELECT c1.FoundPostID                           AS Post_ID,
       f.Title                                  AS Title,
       u1.FirstName || ' ' || u1.LastName       AS Claimant_1,
       s1.StatusName                            AS Result_1,
       u2.FirstName || ' ' || u2.LastName       AS Claimant_2,
       s2.StatusName                            AS Result_2,
       CASE WHEN c1.RequestDate <= c2.RequestDate THEN u1.FirstName
            ELSE u2.FirstName END               AS First_To_Claim,
       ABS(c2.RequestDate - c1.RequestDate)     AS Days_Apart
  FROM ClaimRequest c1
  JOIN ClaimRequest c2           ON c2.FoundPostID = c1.FoundPostID
                                AND c2.RequestID   > c1.RequestID
  JOIN FoundPost f               ON f.FoundPostID  = c1.FoundPostID
  JOIN Users u1                  ON u1.UserID      = c1.UserID
  JOIN Users u2                  ON u2.UserID      = c2.UserID
  JOIN ClaimStatus s1            ON s1.StatusID    = c1.StatusID
  JOIN ClaimStatus s2            ON s2.StatusID    = c2.StatusID
 ORDER BY c1.FoundPostID;
