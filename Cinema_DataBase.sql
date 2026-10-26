CREATE DATABASE CINEMA;
USE CINEMA;


-- 1. Bảng Vai trò (Roles)
CREATE TABLE Roles (
    RoleID INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(50) NOT NULL UNIQUE -- 'CUSTOMER', 'STAFF', 'ADMIN'
);

-- 2. Bảng Người dùng (Users)
CREATE TABLE Users (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL, -- Mật khẩu đã được mã hóa bằng bcrypt/argon2
    PhoneNumber VARCHAR(15) NULL,
    RoleID INT NOT NULL DEFAULT 1, -- Mặc định là CUSTOMER
    CreatedAt DATETIME DEFAULT GETDATE(),
    IsActive BIT DEFAULT 1,
    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleID) REFERENCES Roles(RoleID)
);

-- 3. Bảng Refresh Tokens (Dùng để quản lý phiên đăng nhập lâu dài cho JWT)
CREATE TABLE RefreshTokens (
    TokenID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    Token VARCHAR(500) NOT NULL UNIQUE,
    ExpiresAt DATETIME NOT NULL,
    IsRevoked BIT DEFAULT 0, -- Set = 1 khi người dùng Logout
    CreatedAt DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
);

-- Thêm sẵn dữ liệu mặc định cho bảng Roles
INSERT INTO Roles (RoleName) VALUES ('CUSTOMER'), ('STAFF'), ('ADMIN');


-- 4. Bảng Phim (Movies)
CREATE TABLE Movies (
    MovieID INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    Duration INT NOT NULL, -- Thời lượng tính bằng phút
    ReleaseDate DATE NOT NULL,
    Director NVARCHAR(100) NULL,
    PosterURL VARCHAR(500) NULL,
    Status INT DEFAULT 1 -- 1: Đang chiếu, 2: Sắp chiếu, 0: Ngừng chiếu
);

-- 5. Bảng Phòng chiếu (Rooms)
CREATE TABLE Rooms (
    RoomID INT IDENTITY(1,1) PRIMARY KEY,
    RoomName NVARCHAR(50) NOT NULL, -- Ví dụ: Phòng 01, Phòng IMAX
    TotalSeats INT NOT NULL
);

-- 6. Bảng Ghế ngồi (Seats)
CREATE TABLE Seats (
    SeatID INT IDENTITY(1,1) PRIMARY KEY,
    RoomID INT NOT NULL,
    RowName VARCHAR(5) NOT NULL, -- Ví dụ: A, B, C...
    SeatNumber INT NOT NULL, -- Ví dụ: 1, 2, 3...
    SeatType VARCHAR(20) DEFAULT 'STANDARD', -- 'STANDARD', 'VIP', 'COUPLE'
    CONSTRAINT FK_Seats_Rooms FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID) ON DELETE CASCADE
);

-- 7. Bảng Lịch chiếu (Showtimes)
CREATE TABLE Showtimes (
    ShowtimeID INT IDENTITY(1,1) PRIMARY KEY,
    MovieID INT NOT NULL,
    RoomID INT NOT NULL,
    StartTime DATETIME NOT NULL,
    Price DECIMAL(18, 2) NOT NULL, -- Giá vé cơ bản
    CONSTRAINT FK_Showtimes_Movies FOREIGN KEY (MovieID) REFERENCES Movies(MovieID),
    CONSTRAINT FK_Showtimes_Rooms FOREIGN KEY (RoomID) REFERENCES Rooms(RoomID)
);

-- 8. Bảng Đặt vé (Bookings)
CREATE TABLE Bookings (
    BookingID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL, -- Liên kết với bảng Users (khách hàng đặt vé)
    ShowtimeID INT NOT NULL,
    BookingTime DATETIME DEFAULT GETDATE(),
    TotalPrice DECIMAL(18, 2) NOT NULL,
    Status VARCHAR(20) DEFAULT 'PENDING', -- 'PENDING', 'PAID', 'CANCELLED'
    CONSTRAINT FK_Bookings_Users FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT FK_Bookings_Showtimes FOREIGN KEY (ShowtimeID) REFERENCES Showtimes(ShowtimeID)
);

-- 9. Bảng Chi tiết ghế đặt (BookingDetails)
CREATE TABLE BookingDetails (
    BookingDetailID INT IDENTITY(1,1) PRIMARY KEY,
    BookingID INT NOT NULL,
    SeatID INT NOT NULL,
    Price DECIMAL(18, 2) NOT NULL, -- Giá tiền của ghế tại thời điểm đặt
    CONSTRAINT FK_BookingDetails_Bookings FOREIGN KEY (BookingID) REFERENCES Bookings(BookingID) ON DELETE CASCADE,
    CONSTRAINT FK_BookingDetails_Seats FOREIGN KEY (SeatID) REFERENCES Seats(SeatID)
);



CREATE TABLE Tickets (
    TicketID    INT IDENTITY(1,1) PRIMARY KEY,
    TicketCode  VARCHAR(30)   NOT NULL UNIQUE,           -- mã vé duy nhất, vd: TK-20261025-8F3A2C1B
    BookingID   INT           NOT NULL,                  -- vé thuộc đơn đặt nào
    UserID      INT           NOT NULL,                  -- người mua
    MovieID     INT           NOT NULL,                  -- phim
    ShowtimeID  INT           NOT NULL,                  -- suất chiếu
    SeatID      INT           NOT NULL,                  -- ghế
    Price       DECIMAL(18,2) NOT NULL,                  -- giá vé tại thời điểm mua
    Status      VARCHAR(20)   NOT NULL DEFAULT 'UNUSED', -- UNUSED: chưa dùng, USED: đã dùng, CANCELLED: bị hủy
    UsedAt      DATETIME      NULL,                      -- thời điểm quét vé thành công
    CreatedAt   DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CK_Tickets_Status    CHECK (Status IN ('UNUSED', 'USED', 'CANCELLED')),
    CONSTRAINT FK_Tickets_Bookings  FOREIGN KEY (BookingID)  REFERENCES Bookings(BookingID),
    CONSTRAINT FK_Tickets_Users     FOREIGN KEY (UserID)     REFERENCES Users(UserID),
    CONSTRAINT FK_Tickets_Movies    FOREIGN KEY (MovieID)    REFERENCES Movies(MovieID),
    CONSTRAINT FK_Tickets_Showtimes FOREIGN KEY (ShowtimeID) REFERENCES Showtimes(ShowtimeID),
    CONSTRAINT FK_Tickets_Seats     FOREIGN KEY (SeatID)     REFERENCES Seats(SeatID)
);
GO

-- Chặn đặt trùng ghế: 1 ghế trong 1 suất chiếu chỉ có 1 vé còn hiệu lực
-- (vé đã CANCELLED thì ghế được đặt lại)
CREATE UNIQUE INDEX UX_Tickets_Showtime_Seat
    ON Tickets (ShowtimeID, SeatID)
    WHERE Status <> 'CANCELLED';
GO

CREATE INDEX IX_Tickets_UserID    ON Tickets (UserID);
CREATE INDEX IX_Tickets_BookingID ON Tickets (BookingID);
GO



USE CINEMA;
GO

SET NOCOUNT ON;

--------------------------------------------------
-- 1. ROLES
--------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleName = 'CUSTOMER')
    INSERT INTO Roles (RoleName) VALUES ('CUSTOMER');

IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleName = 'STAFF')
    INSERT INTO Roles (RoleName) VALUES ('STAFF');

IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleName = 'ADMIN')
    INSERT INTO Roles (RoleName) VALUES ('ADMIN');


--------------------------------------------------
-- 2. USERS
-- PasswordHash bên dưới chỉ là dữ liệu demo.
-- Chưa dùng được để đăng nhập bằng BCrypt.
--------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'customer@cinema.test')
    INSERT INTO Users
        (FullName, Email, PasswordHash, PhoneNumber, RoleID)
    VALUES
        (N'Nguyễn Văn An', 'customer@cinema.test',
         'DEMO_HASH_CUSTOMER', '0901000001',
         (SELECT RoleID FROM Roles WHERE RoleName = 'CUSTOMER'));

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'staff@cinema.test')
    INSERT INTO Users
        (FullName, Email, PasswordHash, PhoneNumber, RoleID)
    VALUES
        (N'Trần Thị Bình', 'staff@cinema.test',
         'DEMO_HASH_STAFF', '0901000002',
         (SELECT RoleID FROM Roles WHERE RoleName = 'STAFF'));

IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'admin@cinema.test')
    INSERT INTO Users
        (FullName, Email, PasswordHash, PhoneNumber, RoleID)
    VALUES
        (N'Lê Minh Hoàng', 'admin@cinema.test',
         'DEMO_HASH_ADMIN', '0901000003',
         (SELECT RoleID FROM Roles WHERE RoleName = 'ADMIN'));


--------------------------------------------------
-- 3. MOVIES
-- Status: 1 = Đang chiếu, 2 = Sắp chiếu
--------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Movies WHERE Title = N'Đào, Phở và Piano')
    INSERT INTO Movies
        (Title, Description, Duration, ReleaseDate, Director, PosterURL, Status)
    VALUES
        (N'Đào, Phở và Piano',
         N'Phim lịch sử Việt Nam dùng cho dữ liệu kiểm thử.',
         100, '2024-02-10', N'Phi Tiến Sơn', NULL, 1);

IF NOT EXISTS (SELECT 1 FROM Movies WHERE Title = N'Mắt Biếc')
    INSERT INTO Movies
        (Title, Description, Duration, ReleaseDate, Director, PosterURL, Status)
    VALUES
        (N'Mắt Biếc',
         N'Câu chuyện tình cảm và tuổi trẻ.',
         117, '2019-12-20', N'Victor Vũ', NULL, 1);

IF NOT EXISTS (SELECT 1 FROM Movies WHERE Title = N'Lật Mặt')
    INSERT INTO Movies
        (Title, Description, Duration, ReleaseDate, Director, PosterURL, Status)
    VALUES
        (N'Lật Mặt',
         N'Phim giải trí Việt Nam dùng để thử API.',
         110, '2024-04-26', N'Lý Hải', NULL, 1);

IF NOT EXISTS (SELECT 1 FROM Movies WHERE Title = N'Bầu Trời Tương Lai')
    INSERT INTO Movies
        (Title, Description, Duration, ReleaseDate, Director, PosterURL, Status)
    VALUES
        (N'Bầu Trời Tương Lai',
         N'Phim khoa học viễn tưởng mẫu.',
         125, '2027-01-15', N'Nguyễn Minh', NULL, 2);

IF NOT EXISTS (SELECT 1 FROM Movies WHERE Title = N'Hành Trình Bí Ẩn')
    INSERT INTO Movies
        (Title, Description, Duration, ReleaseDate, Director, PosterURL, Status)
    VALUES
        (N'Hành Trình Bí Ẩn',
         N'Phim phiêu lưu mẫu dùng cho kiểm thử.',
         105, '2027-02-20', N'Trần Nam', NULL, 2);


--------------------------------------------------
-- 4. ROOMS
--------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM Rooms WHERE RoomName = N'Phòng 01')
    INSERT INTO Rooms (RoomName, TotalSeats) VALUES (N'Phòng 01', 30);

IF NOT EXISTS (SELECT 1 FROM Rooms WHERE RoomName = N'Phòng 02')
    INSERT INTO Rooms (RoomName, TotalSeats) VALUES (N'Phòng 02', 30);

IF NOT EXISTS (SELECT 1 FROM Rooms WHERE RoomName = N'Phòng VIP')
    INSERT INTO Rooms (RoomName, TotalSeats) VALUES (N'Phòng VIP', 30);


--------------------------------------------------
-- 5. SEATS
-- Mỗi phòng: 5 hàng A-E, mỗi hàng 6 ghế.
-- Ghế hàng E là VIP.
--------------------------------------------------
DECLARE @RoomID INT;
DECLARE @RowNumber INT;
DECLARE @SeatNumber INT;
DECLARE @RowName VARCHAR(5);

DECLARE RoomCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT RoomID
    FROM Rooms
    WHERE RoomName IN (N'Phòng 01', N'Phòng 02', N'Phòng VIP');

OPEN RoomCursor;
FETCH NEXT FROM RoomCursor INTO @RoomID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @RowNumber = 0;

    WHILE @RowNumber < 5
    BEGIN
        SET @RowName = CHAR(65 + @RowNumber);
        SET @SeatNumber = 1;

        WHILE @SeatNumber <= 6
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM Seats
                WHERE RoomID = @RoomID
                  AND RowName = @RowName
                  AND SeatNumber = @SeatNumber
            )
            BEGIN
                INSERT INTO Seats
                    (RoomID, RowName, SeatNumber, SeatType)
                VALUES
                    (@RoomID, @RowName, @SeatNumber,
                     CASE
                         WHEN @RowNumber = 4 THEN 'VIP'
                         ELSE 'STANDARD'
                     END);
            END;

            SET @SeatNumber = @SeatNumber + 1;
        END;

        SET @RowNumber = @RowNumber + 1;
    END;

    FETCH NEXT FROM RoomCursor INTO @RoomID;
END;

CLOSE RoomCursor;
DEALLOCATE RoomCursor;


--------------------------------------------------
-- 6. SHOWTIMES
-- Tạo lịch chiếu trong tương lai tương đối với ngày chạy.
--------------------------------------------------
DECLARE @Movie1 INT = (SELECT TOP 1 MovieID FROM Movies WHERE Title = N'Đào, Phở và Piano');
DECLARE @Movie2 INT = (SELECT TOP 1 MovieID FROM Movies WHERE Title = N'Mắt Biếc');
DECLARE @Movie3 INT = (SELECT TOP 1 MovieID FROM Movies WHERE Title = N'Lật Mặt');
DECLARE @Room1 INT = (SELECT TOP 1 RoomID FROM Rooms WHERE RoomName = N'Phòng 01');
DECLARE @Room2 INT = (SELECT TOP 1 RoomID FROM Rooms WHERE RoomName = N'Phòng 02');
DECLARE @RoomVIP INT = (SELECT TOP 1 RoomID FROM Rooms WHERE RoomName = N'Phòng VIP');

IF NOT EXISTS (
    SELECT 1 FROM Showtimes
    WHERE MovieID = @Movie1 AND RoomID = @Room1
      AND StartTime = DATEADD(HOUR, 2, CONVERT(DATETIME, CONVERT(DATE, GETDATE())))
)
    INSERT INTO Showtimes (MovieID, RoomID, StartTime, Price)
    VALUES (@Movie1, @Room1,
            DATEADD(HOUR, 2, CONVERT(DATETIME, CONVERT(DATE, GETDATE()))),
            75000);

IF NOT EXISTS (
    SELECT 1 FROM Showtimes
    WHERE MovieID = @Movie2 AND RoomID = @Room2
      AND StartTime = DATEADD(HOUR, 5, CONVERT(DATETIME, CONVERT(DATE, GETDATE())))
)
    INSERT INTO Showtimes (MovieID, RoomID, StartTime, Price)
    VALUES (@Movie2, @Room2,
            DATEADD(HOUR, 5, CONVERT(DATETIME, CONVERT(DATE, GETDATE()))),
            85000);

IF NOT EXISTS (
    SELECT 1 FROM Showtimes
    WHERE MovieID = @Movie3 AND RoomID = @RoomVIP
      AND StartTime = DATEADD(DAY, 1, DATEADD(HOUR, 3, CONVERT(DATETIME, CONVERT(DATE, GETDATE()))))
)
    INSERT INTO Showtimes (MovieID, RoomID, StartTime, Price)
    VALUES (@Movie3, @RoomVIP,
            DATEADD(DAY, 1, DATEADD(HOUR, 3, CONVERT(DATETIME, CONVERT(DATE, GETDATE())))),
            100000);


--------------------------------------------------
-- 7. BOOKINGS, BOOKING DETAILS, TICKETS
-- Tạo một đơn đặt vé mẫu cho CUSTOMER.
--------------------------------------------------
DECLARE @UserID INT =
    (SELECT TOP 1 UserID FROM Users WHERE Email = 'customer@cinema.test');

DECLARE @ShowtimeID INT =
    (SELECT TOP 1 ShowtimeID FROM Showtimes
     WHERE MovieID = @Movie1 AND RoomID = @Room1
     ORDER BY StartTime);

DECLARE @SeatID INT =
    (SELECT TOP 1 SeatID FROM Seats
     WHERE RoomID = @Room1 AND RowName = 'A' AND SeatNumber = 1);

DECLARE @TicketPrice DECIMAL(18,2) =
    (SELECT Price FROM Showtimes WHERE ShowtimeID = @ShowtimeID);

IF @UserID IS NOT NULL
   AND @ShowtimeID IS NOT NULL
   AND @SeatID IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM Tickets
       WHERE ShowtimeID = @ShowtimeID
         AND SeatID = @SeatID
         AND Status <> 'CANCELLED'
   )
BEGIN
    DECLARE @BookingID INT;

    INSERT INTO Bookings (UserID, ShowtimeID, TotalPrice, Status)
    VALUES (@UserID, @ShowtimeID, @TicketPrice, 'PAID');

    SET @BookingID = SCOPE_IDENTITY();

    INSERT INTO BookingDetails (BookingID, SeatID, Price)
    VALUES (@BookingID, @SeatID, @TicketPrice);

    INSERT INTO Tickets
        (TicketCode, BookingID, UserID, MovieID, ShowtimeID, SeatID, Price, Status)
    VALUES
        ('DEMO-' + CONVERT(VARCHAR(8), GETDATE(), 112) + '-0001',
         @BookingID, @UserID, @Movie1, @ShowtimeID, @SeatID,
         @TicketPrice, 'UNUSED');
END;


--------------------------------------------------
-- 8. KIỂM TRA DỮ LIỆU
--------------------------------------------------
SELECT * FROM Roles;
SELECT UserID, FullName, Email, PhoneNumber, RoleID FROM Users;
SELECT MovieID, Title, ReleaseDate, Status FROM Movies;
SELECT * FROM Rooms;
SELECT * FROM Seats ORDER BY RoomID, RowName, SeatNumber;
SELECT * FROM Showtimes ORDER BY StartTime;
SELECT * FROM Bookings;
SELECT * FROM BookingDetails;
SELECT * FROM Tickets;
GO


