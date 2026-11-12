-- SE : ระบบประกาศของหาย-ของพบ คณะวิทยาศาสตร์ (อิง ER เขียนเอง)
-- ล้างตารางเดิมทั้งหมด
BEGIN
    FOR t IN (SELECT table_name FROM user_tables) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;
END;
/
BEGIN
    FOR v IN (SELECT view_name FROM user_views) LOOP
        EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
    END LOOP;
END;
/
PURGE RECYCLEBIN;

-- create table

-- ===== Setup Table =====

-- 1. USERROLE (ประเภทผู้ใช้งาน)
CREATE TABLE UserRole (
    RoleID      VARCHAR2(10) PRIMARY KEY,
    RoleName    NVARCHAR2(50)
);

-- 2. CATEGORY (ประเภทของสิ่งของ)
CREATE TABLE Category (
    CategoryID      VARCHAR2(10) PRIMARY KEY,
    CategoryName    NVARCHAR2(100)
);

-- 3. POSTSTATUS (สถานะของประกาศของหาย / ประกาศพบ)
CREATE TABLE PostStatus (
    StatusID    VARCHAR2(10) PRIMARY KEY,
    StatusName  NVARCHAR2(50)
);

-- 4. CLAIMSTATUS (สถานะของคำขอของคืน)
CREATE TABLE ClaimStatus (
    StatusID    VARCHAR2(10) PRIMARY KEY,
    StatusName  NVARCHAR2(50)
);

-- ===== Master Table =====

-- 5. USERS (ผู้ใช้งาน : แอดมินคือผู้ใช้งานที่มี Role = Admin)
CREATE TABLE Users (
    UserID      VARCHAR2(10) PRIMARY KEY,
    FirstName   NVARCHAR2(100),
    LastName    NVARCHAR2(100),
    Phone       VARCHAR2(15),
    Email       VARCHAR2(100),
    Address     NVARCHAR2(255),
    RoleID      VARCHAR2(10),
    CONSTRAINT FK_Users_Role FOREIGN KEY (RoleID)
        REFERENCES UserRole(RoleID)
);

-- 6. FOUNDPOST (ประกาศพบของ : โพสต์โดยแอดมิน)
CREATE TABLE FoundPost (
    FoundPostID     VARCHAR2(10) PRIMARY KEY,
    Title           NVARCHAR2(255),
    ItemName        NVARCHAR2(100),
    FinderName      NVARCHAR2(100),
    FinderPhone     VARCHAR2(15),
    FinderEmail     VARCHAR2(100),
    FinderAddress   NVARCHAR2(255),
    ImageURL        VARCHAR2(500),
    FoundLocation   NVARCHAR2(255),
    StatusID        VARCHAR2(10),
    PostDate        DATE,
    FoundDate       DATE,
    UserID          VARCHAR2(10),
    CONSTRAINT FK_FoundPost_Status FOREIGN KEY (StatusID)
        REFERENCES PostStatus(StatusID),
    CONSTRAINT FK_FoundPost_User FOREIGN KEY (UserID)
        REFERENCES Users(UserID)
);

-- 7. LOSTPOST (ประกาศหาของหาย : สร้างโดยผู้ใช้งาน)
CREATE TABLE LostPost (
    LostPostID  VARCHAR2(10) PRIMARY KEY,
    Title       NVARCHAR2(255),
    PostDate    DATE,
    StatusID    VARCHAR2(10),
    UserID      VARCHAR2(10),
    CONSTRAINT FK_LostPost_Status FOREIGN KEY (StatusID)
        REFERENCES PostStatus(StatusID),
    CONSTRAINT FK_LostPost_User FOREIGN KEY (UserID)
        REFERENCES Users(UserID)
);

-- ===== Transaction Table =====

-- 8. CLAIMREQUEST (คำขอของคืน)
CREATE TABLE ClaimRequest (
    RequestID       VARCHAR2(10) PRIMARY KEY,
    FoundPostID     VARCHAR2(10),
    UserID          VARCHAR2(10),
    StatusID        VARCHAR2(10),
    RequestDate     DATE,
    Detail          NVARCHAR2(500),
    CONSTRAINT FK_Claim_FoundPost FOREIGN KEY (FoundPostID)
        REFERENCES FoundPost(FoundPostID),
    CONSTRAINT FK_Claim_User FOREIGN KEY (UserID)
        REFERENCES Users(UserID),
    CONSTRAINT FK_Claim_Status FOREIGN KEY (StatusID)
        REFERENCES ClaimStatus(StatusID)
);

-- 9. FOUNDPOSTCATEGORY (รายการประเภท ของประกาศพบ : weak entity)
CREATE TABLE FoundPostCategory (
    FoundPostID     VARCHAR2(10),
    LineNo          NUMBER(5),
    CategoryID      VARCHAR2(10),
    CONSTRAINT PK_FoundPostCategory PRIMARY KEY (FoundPostID, LineNo),
    CONSTRAINT FK_FPC_FoundPost FOREIGN KEY (FoundPostID)
        REFERENCES FoundPost(FoundPostID),
    CONSTRAINT FK_FPC_Category FOREIGN KEY (CategoryID)
        REFERENCES Category(CategoryID)
);

-- 10. LOSTPOSTCATEGORY (รายการประเภท ของประกาศหาย : weak entity)
CREATE TABLE LostPostCategory (
    LostPostID      VARCHAR2(10),
    LineNo          NUMBER(5),
    CategoryID      VARCHAR2(10),
    CONSTRAINT PK_LostPostCategory PRIMARY KEY (LostPostID, LineNo),
    CONSTRAINT FK_LPC_LostPost FOREIGN KEY (LostPostID)
        REFERENCES LostPost(LostPostID),
    CONSTRAINT FK_LPC_Category FOREIGN KEY (CategoryID)
        REFERENCES Category(CategoryID)
);

-----------------------------
-- เพิ่ม Business Constraints
-----------------------------

-- ชื่อ Setup ต้องไม่ว่างและห้ามซ้ำ
ALTER TABLE UserRole MODIFY (RoleName NVARCHAR2(50) NOT NULL);
ALTER TABLE UserRole ADD CONSTRAINT UQ_Role_Name UNIQUE (RoleName);
ALTER TABLE Category MODIFY (CategoryName NVARCHAR2(100) NOT NULL);
ALTER TABLE Category ADD CONSTRAINT UQ_Category_Name UNIQUE (CategoryName);
ALTER TABLE PostStatus MODIFY (StatusName NVARCHAR2(50) NOT NULL);
ALTER TABLE PostStatus ADD CONSTRAINT UQ_PostStatus_Name UNIQUE (StatusName);
ALTER TABLE ClaimStatus MODIFY (StatusName NVARCHAR2(50) NOT NULL);
ALTER TABLE ClaimStatus ADD CONSTRAINT UQ_ClaimStatus_Name UNIQUE (StatusName);

-- ผู้ใช้งานต้องมีชื่อและ Role
ALTER TABLE Users MODIFY (FirstName NVARCHAR2(100) NOT NULL);
ALTER TABLE Users MODIFY (RoleID VARCHAR2(10) NOT NULL);

-- อีเมลต้องมี @
ALTER TABLE Users
  ADD CONSTRAINT CK_Users_Email
  CHECK (Email IS NULL OR Email LIKE '%_@_%')
  ENABLE VALIDATE;

-- ประกาศพบต้องมีชื่อประกาศ ผู้โพสต์ และสถานะ
ALTER TABLE FoundPost MODIFY (Title NVARCHAR2(255) NOT NULL);
ALTER TABLE FoundPost MODIFY (UserID VARCHAR2(10) NOT NULL);
ALTER TABLE FoundPost MODIFY (StatusID VARCHAR2(10) NOT NULL);

-- วันที่ประกาศต้องไม่ก่อนวันที่พบ
ALTER TABLE FoundPost
  ADD CONSTRAINT CK_FoundPost_Date
  CHECK (FoundDate IS NULL OR PostDate >= FoundDate)
  ENABLE VALIDATE;

-- ประกาศหาของหายต้องมีชื่อประกาศ ผู้สร้าง และสถานะ
ALTER TABLE LostPost MODIFY (Title NVARCHAR2(255) NOT NULL);
ALTER TABLE LostPost MODIFY (UserID VARCHAR2(10) NOT NULL);
ALTER TABLE LostPost MODIFY (StatusID VARCHAR2(10) NOT NULL);

-- คำขอคืนต้องอ้างถึงประกาศ ผู้ใช้ และสถานะ
ALTER TABLE ClaimRequest MODIFY (FoundPostID VARCHAR2(10) NOT NULL);
ALTER TABLE ClaimRequest MODIFY (UserID VARCHAR2(10) NOT NULL);
ALTER TABLE ClaimRequest MODIFY (StatusID VARCHAR2(10) NOT NULL);

-- 1 ประกาศ ห้ามติดประเภทเดิมซ้ำ
ALTER TABLE FoundPostCategory MODIFY (CategoryID VARCHAR2(10) NOT NULL);
ALTER TABLE FoundPostCategory ADD CONSTRAINT UQ_FPC_PostCat UNIQUE (FoundPostID, CategoryID);
ALTER TABLE LostPostCategory MODIFY (CategoryID VARCHAR2(10) NOT NULL);
ALTER TABLE LostPostCategory ADD CONSTRAINT UQ_LPC_PostCat UNIQUE (LostPostID, CategoryID);

COMMIT;
