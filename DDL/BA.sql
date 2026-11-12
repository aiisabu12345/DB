-- BA : ระบบขออนุญาตเดินทางและเบิกค่าใช้จ่าย (บริษัทขายปลีกวัสดุก่อสร้าง) (อิง ER เขียนเอง)
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

-- 1. DEPARTMENT (แผนก : ManagerID = ผู้บริหารแผนกปัจจุบัน 1:1)
CREATE TABLE Department (
    DeptID      VARCHAR2(10) PRIMARY KEY,
    DeptName    NVARCHAR2(100),
    ManagerID   VARCHAR2(10)
);

-- 2. TRANSFERTYPE (ประเภทหลักฐานการโอน)
CREATE TABLE TransferType (
    TypeID      VARCHAR2(10) PRIMARY KEY,
    TypeName    NVARCHAR2(100)
);

-- 3. REQUESTSTATUS (สถานะของเอกสารคำขอ : FlowOrder = ลำดับขั้นใน flow แก้/เพิ่มขั้นได้โดยไม่ต้องแก้ตารางอื่น)
CREATE TABLE RequestStatus (
    StatusID    VARCHAR2(10) PRIMARY KEY,
    StatusName  NVARCHAR2(50),
    FlowOrder   NUMBER(3)
);

-- ===== Master Table =====

-- 4. EMPLOYEE (พนักงาน)
CREATE TABLE Employee (
    EmpID       VARCHAR2(10) PRIMARY KEY,
    FirstName   NVARCHAR2(100),
    LastName    NVARCHAR2(100),
    Phone       VARCHAR2(15),
    DeptID      VARCHAR2(10),
    HireDate    DATE,
    ResignDate  DATE,
    CONSTRAINT FK_Emp_Dept FOREIGN KEY (DeptID)
        REFERENCES Department(DeptID)
);

-- ผู้บริหารแผนกต้องเป็นพนักงาน (สร้างหลัง Employee เพราะอ้างอิงวนกัน)
ALTER TABLE Department
  ADD CONSTRAINT FK_Dept_Manager FOREIGN KEY (ManagerID)
      REFERENCES Employee(EmpID);

-- 5. TRAVELREQUEST (เอกสารคำขออนุมัติการเดินทาง)
CREATE TABLE TravelRequest (
    RequestID       VARCHAR2(10) PRIMARY KEY,
    EmpID           VARCHAR2(10),
    WriteDate       DATE,
    Purpose         NVARCHAR2(255),
    Destination     NVARCHAR2(255),
    StartDate       DATE,
    EndDate         DATE,
    TotalDays       NUMBER(3),
    StatusID        VARCHAR2(10),
    AccountNo       VARCHAR2(20),
    AccountName     NVARCHAR2(100),
    DisburseDate    DATE,
    RequestAmount   NUMBER(12,2),
    ActualAmount    NUMBER(12,2),
    ExpectedResult  NVARCHAR2(500),
    CONSTRAINT FK_TR_Emp FOREIGN KEY (EmpID)
        REFERENCES Employee(EmpID),
    CONSTRAINT FK_TR_Status FOREIGN KEY (StatusID)
        REFERENCES RequestStatus(StatusID)
);

-- ===== Transaction Table =====

-- 6. MANAGEMENTHISTORY (ประวัติการบริหารแผนก : weak entity ของ Department)
CREATE TABLE ManagementHistory (
    DeptID      VARCHAR2(10),
    LineNo      NUMBER(5),
    EmpID       VARCHAR2(10),
    StartDate   DATE,
    EndDate     DATE,
    CONSTRAINT PK_ManagementHistory PRIMARY KEY (DeptID, LineNo),
    CONSTRAINT FK_MH_Dept FOREIGN KEY (DeptID)
        REFERENCES Department(DeptID),
    CONSTRAINT FK_MH_Emp FOREIGN KEY (EmpID)
        REFERENCES Employee(EmpID)
);

-- 7. STATUSAPPROVER (ผู้มีสิทธิ์อนุมัติในแต่ละสถานะ : weak entity ของ RequestStatus)
CREATE TABLE StatusApprover (
    StatusID    VARCHAR2(10),
    LineNo      NUMBER(5),
    EmpID       VARCHAR2(10),
    CONSTRAINT PK_StatusApprover PRIMARY KEY (StatusID, LineNo),
    CONSTRAINT FK_SA_Status FOREIGN KEY (StatusID)
        REFERENCES RequestStatus(StatusID),
    CONSTRAINT FK_SA_Emp FOREIGN KEY (EmpID)
        REFERENCES Employee(EmpID),
    CONSTRAINT UQ_SA_StatusEmp UNIQUE (StatusID, EmpID)
);

-- 8. TRAVELCOMPANION (พนักงานที่ร่วมเดินทาง : weak entity ของ TravelRequest)
CREATE TABLE TravelCompanion (
    RequestID   VARCHAR2(10),
    LineNo      NUMBER(5),
    EmpID       VARCHAR2(10),
    CONSTRAINT PK_TravelCompanion PRIMARY KEY (RequestID, LineNo),
    CONSTRAINT FK_TC_Request FOREIGN KEY (RequestID)
        REFERENCES TravelRequest(RequestID),
    CONSTRAINT FK_TC_Emp FOREIGN KEY (EmpID)
        REFERENCES Employee(EmpID)
);

-- 9. ADVANCEEXPENSEITEM (รายการค่าใช้จ่ายล่วงหน้า : weak entity ของ TravelRequest)
CREATE TABLE AdvanceExpenseItem (
    RequestID   VARCHAR2(10),
    LineNo      NUMBER(5),
    ItemName    NVARCHAR2(255),
    UnitPrice   NUMBER(12,2),
    Quantity    NUMBER(5),
    CONSTRAINT PK_AdvanceExpenseItem PRIMARY KEY (RequestID, LineNo),
    CONSTRAINT FK_AEI_Request FOREIGN KEY (RequestID)
        REFERENCES TravelRequest(RequestID)
);

-- 10. APPROVALSIGNATURE (การลงนามอนุมัติ : weak entity ของ TravelRequest
--     ผู้ลงนามต้องอยู่ใน StatusApprover ของสถานะที่ลงนาม)
CREATE TABLE ApprovalSignature (
    RequestID       VARCHAR2(10),
    LineNo          NUMBER(5),
    StatusID        VARCHAR2(10),
    EmpID           VARCHAR2(10),
    SignDate        DATE,
    Result          NVARCHAR2(20),
    RejectReason    NVARCHAR2(500),
    CONSTRAINT PK_ApprovalSignature PRIMARY KEY (RequestID, LineNo),
    CONSTRAINT FK_AS_Request FOREIGN KEY (RequestID)
        REFERENCES TravelRequest(RequestID),
    CONSTRAINT FK_AS_Approver FOREIGN KEY (StatusID, EmpID)
        REFERENCES StatusApprover(StatusID, EmpID)
);

-- 11. TRAVELEVIDENCE (หลักฐานการเดินทาง / การใช้เงินจริง : weak entity ของ TravelRequest)
CREATE TABLE TravelEvidence (
    RequestID   VARCHAR2(10),
    LineNo      NUMBER(5),
    UsedDate    DATE,
    ItemName    NVARCHAR2(255),
    Amount      NUMBER(12,2),
    SlipURL     VARCHAR2(500),
    CONSTRAINT PK_TravelEvidence PRIMARY KEY (RequestID, LineNo),
    CONSTRAINT FK_TE_Request FOREIGN KEY (RequestID)
        REFERENCES TravelRequest(RequestID)
);

-- 12. TRANSFEREVIDENCE (หลักฐานการโอน : สำรองจ่าย / คืนเงินที่ใช้เหลือ / เบิกเงินที่ใช้เกิน)
CREATE TABLE TransferEvidence (
    EvidenceID      VARCHAR2(10) PRIMARY KEY,
    RequestID       VARCHAR2(10),
    TypeID          VARCHAR2(10),
    TransferDate    DATE,
    Amount          NUMBER(12,2),
    Bank            NVARCHAR2(100),
    AccountOwner    NVARCHAR2(100),
    RefNo           VARCHAR2(50),
    SlipURL         VARCHAR2(500),
    CONSTRAINT FK_TFE_Request FOREIGN KEY (RequestID)
        REFERENCES TravelRequest(RequestID),
    CONSTRAINT FK_TFE_Type FOREIGN KEY (TypeID)
        REFERENCES TransferType(TypeID)
);

-----------------------------
-- เพิ่ม Business Constraints
-----------------------------

-- ชื่อ Setup ต้องไม่ว่างและห้ามซ้ำ
ALTER TABLE Department MODIFY (DeptName NVARCHAR2(100) NOT NULL);
ALTER TABLE Department ADD CONSTRAINT UQ_Dept_Name UNIQUE (DeptName);
ALTER TABLE TransferType MODIFY (TypeName NVARCHAR2(100) NOT NULL);
ALTER TABLE TransferType ADD CONSTRAINT UQ_TransferType_Name UNIQUE (TypeName);
ALTER TABLE RequestStatus MODIFY (StatusName NVARCHAR2(50) NOT NULL);
ALTER TABLE RequestStatus ADD CONSTRAINT UQ_RequestStatus_Name UNIQUE (StatusName);

-- ลำดับ flow ห้ามซ้ำ (สถานะนอก flow เช่น ไม่อนุมัติ ให้ FlowOrder เป็น NULL)
ALTER TABLE RequestStatus ADD CONSTRAINT UQ_RequestStatus_Flow UNIQUE (FlowOrder);

-- ผู้บริหาร 1 คน บริหารได้แค่ 1 แผนก
ALTER TABLE Department ADD CONSTRAINT UQ_Dept_Manager UNIQUE (ManagerID);

-- พนักงานต้องมีชื่อและสังกัดแผนก
ALTER TABLE Employee MODIFY (FirstName NVARCHAR2(100) NOT NULL);
ALTER TABLE Employee MODIFY (DeptID VARCHAR2(10) NOT NULL);

-- วันออกจากงานต้องไม่ก่อนวันเริ่มงาน
ALTER TABLE Employee
  ADD CONSTRAINT CK_Emp_ResignDate
  CHECK (ResignDate IS NULL OR ResignDate >= HireDate)
  ENABLE VALIDATE;

-- ประวัติการบริหาร วันสิ้นสุดต้องไม่ก่อนวันเริ่ม
ALTER TABLE ManagementHistory MODIFY (EmpID VARCHAR2(10) NOT NULL);
ALTER TABLE ManagementHistory MODIFY (StartDate DATE NOT NULL);
ALTER TABLE ManagementHistory
  ADD CONSTRAINT CK_MH_Date
  CHECK (EndDate IS NULL OR EndDate >= StartDate)
  ENABLE VALIDATE;

-- ผู้อนุมัติในสถานะต้องไม่เป็นค่าว่าง
ALTER TABLE StatusApprover MODIFY (EmpID VARCHAR2(10) NOT NULL);

-- คำขอต้องมีผู้ขอและสถานะ
ALTER TABLE TravelRequest MODIFY (EmpID VARCHAR2(10) NOT NULL);
ALTER TABLE TravelRequest MODIFY (StatusID VARCHAR2(10) NOT NULL);

-- วันสิ้นสุดต้องไม่ก่อนวันเริ่มเดินทาง
ALTER TABLE TravelRequest
  ADD CONSTRAINT CK_TR_Date
  CHECK (EndDate >= StartDate)
  ENABLE VALIDATE;

-- จำนวนวันรวม = วันสิ้นสุด - วันเริ่ม + 1
ALTER TABLE TravelRequest
  ADD CONSTRAINT CK_TR_TotalDays
  CHECK (TotalDays = EndDate - StartDate + 1)
  ENABLE VALIDATE;

-- ยอดเงินต้องไม่ติดลบ
ALTER TABLE TravelRequest
  ADD CONSTRAINT CK_TR_Amount
  CHECK (RequestAmount >= 0 AND (ActualAmount IS NULL OR ActualAmount >= 0))
  ENABLE VALIDATE;

-- 1 คำขอ ห้ามใส่ผู้ร่วมเดินทางคนเดิมซ้ำ
ALTER TABLE TravelCompanion MODIFY (EmpID VARCHAR2(10) NOT NULL);
ALTER TABLE TravelCompanion ADD CONSTRAINT UQ_TC_ReqEmp UNIQUE (RequestID, EmpID);

-- รายการค่าใช้จ่ายล่วงหน้า ราคาและจำนวนต้องมากกว่า 0
ALTER TABLE AdvanceExpenseItem MODIFY (ItemName NVARCHAR2(255) NOT NULL);
ALTER TABLE AdvanceExpenseItem
  ADD CONSTRAINT CK_AEI_Value
  CHECK (UnitPrice > 0 AND Quantity > 0)
  ENABLE VALIDATE;

-- ผลการพิจารณา อนุมัติ / ไม่อนุมัติ และไม่อนุมัติต้องมีเหตุผล
ALTER TABLE ApprovalSignature MODIFY (StatusID VARCHAR2(10) NOT NULL);
ALTER TABLE ApprovalSignature MODIFY (EmpID VARCHAR2(10) NOT NULL);
ALTER TABLE ApprovalSignature
  ADD CONSTRAINT CK_AS_Result
  CHECK (Result IN (N'อนุมัติ', N'ไม่อนุมัติ'))
  ENABLE VALIDATE;
ALTER TABLE ApprovalSignature
  ADD CONSTRAINT CK_AS_Reason
  CHECK (Result = N'อนุมัติ' OR RejectReason IS NOT NULL)
  ENABLE VALIDATE;

-- หลักฐานการเดินทาง จำนวนเงินต้องมากกว่า 0
ALTER TABLE TravelEvidence
  ADD CONSTRAINT CK_TE_Amount
  CHECK (Amount > 0)
  ENABLE VALIDATE;

-- หลักฐานการโอน : 1 คำขอ มีการโอนแต่ละประเภทได้อันเดียว
ALTER TABLE TransferEvidence MODIFY (RequestID VARCHAR2(10) NOT NULL);
ALTER TABLE TransferEvidence MODIFY (TypeID VARCHAR2(10) NOT NULL);
ALTER TABLE TransferEvidence ADD CONSTRAINT UQ_TFE_ReqType UNIQUE (RequestID, TypeID);
ALTER TABLE TransferEvidence
  ADD CONSTRAINT CK_TFE_Amount
  CHECK (Amount > 0)
  ENABLE VALIDATE;

COMMIT;
