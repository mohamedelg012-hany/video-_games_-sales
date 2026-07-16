-----------------------------------------------------
-- Create Database
-----------------------------------------------------

CREATE DATABASE VideoGameSalesDW;


USE VideoGameSalesDW;

CREATE TABLE Dim_Games
(
    Game_ID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(255) NOT NULL,
    Genre NVARCHAR(100) NOT NULL,
    Million_Seller NVARCHAR(10) NOT NULL
);

CREATE TABLE Dim_Platforms
(
    Platform_ID INT IDENTITY(1,1) PRIMARY KEY,
    Platform NVARCHAR(50) NOT NULL,
    Manufacturer NVARCHAR(100) NOT NULL
);


CREATE TABLE Dim_Publishers
(
    Publisher_ID INT IDENTITY(1,1) PRIMARY KEY,
    Publisher NVARCHAR(255) NOT NULL
);


CREATE TABLE Dim_Date
(
    Year_ID INT PRIMARY KEY,
    Year INT NOT NULL, 
    Decade NVARCHAR(20) NOT NULL 
);


CREATE TABLE Fact_Sales
(
    Rank INT PRIMARY KEY,

    Game_ID INT NOT NULL,
    Platform_ID INT NOT NULL,
    Publisher_ID INT NOT NULL,
    Year_ID INT NOT NULL,

    NA_Sales DECIMAL(10,2) NOT NULL, 
    EU_Sales DECIMAL(10,2) NOT NULL, 
    JP_Sales DECIMAL(10,2) NOT NULL,
    Other_Sales DECIMAL(10,2) NOT NULL,
    Global_Sales DECIMAL(10,2) NOT NULL
);


ALTER TABLE Fact_Sales
ADD CONSTRAINT FK_Fact_Game
FOREIGN KEY(Game_ID)
REFERENCES Dim_Games(Game_ID);

ALTER TABLE Fact_Sales
ADD CONSTRAINT FK_Fact_Platform
FOREIGN KEY(Platform_ID)
REFERENCES Dim_Platforms(Platform_ID);

ALTER TABLE Fact_Sales
ADD CONSTRAINT FK_Fact_Publisher
FOREIGN KEY(Publisher_ID)
REFERENCES Dim_Publishers(Publisher_ID);

ALTER TABLE Fact_Sales
ADD CONSTRAINT FK_Fact_Date
FOREIGN KEY(Year_ID)
REFERENCES Dim_Date(Year_ID);

INSERT INTO Dim_Games (Name, Genre, Million_Seller)
SELECT DISTINCT
    Name,
    Genre,
    Million_Seller
FROM VideoGames_Staging;

INSERT INTO Dim_Platforms (Platform, Manufacturer)
SELECT DISTINCT
    Platform,
    Manufacturer
FROM VideoGames_Staging;

INSERT INTO Dim_Publishers (Publisher)
SELECT DISTINCT
    Publisher
FROM VideoGames_Staging;

INSERT INTO Dim_Date (Year_ID, Year, Decade)
SELECT DISTINCT
    Year,
    Year,
    Decade
FROM VideoGames_Staging
WHERE Year IS NOT NULL;

INSERT INTO Fact_Sales
(
    Rank,
    Game_ID,
    Platform_ID,
    Publisher_ID,
    Year_ID,
    NA_Sales,
    EU_Sales,
    JP_Sales,
    Other_Sales,
    Global_Sales
)

SELECT
    S.Rank,
    G.Game_ID,
    P.Platform_ID,
    PU.Publisher_ID,
    D.Year_ID,
    S.NA_Sales,
    S.EU_Sales,
    S.JP_Sales,
    S.Other_Sales,
    S.Global_Sales

FROM VideoGames_Staging S

INNER JOIN Dim_Games G
ON S.Name = G.Name
AND S.Genre = G.Genre
AND S.Million_Seller = G.Million_Seller

INNER JOIN Dim_Platforms P
ON S.Platform = P.Platform
AND S.Manufacturer = P.Manufacturer

INNER JOIN Dim_Publishers PU
ON S.Publisher = PU.Publisher

INNER JOIN Dim_Date D
ON S.Year = D.Year;

SELECT COUNT(*) FROM Dim_Games;

SELECT COUNT(*) FROM Dim_Platforms;

SELECT COUNT(*) FROM Dim_Publishers;

SELECT COUNT(*) FROM Dim_Date;

SELECT COUNT(*) FROM Fact_Sales;


-- 1 Platform Lifespan
SELECT p.Platform, 
       MIN(d.Year) as Launch_Year, 
       MAX(d.Year) as Discontinue_Year,
       (MAX(d.Year) - MIN(d.Year) + 1) as Lifespan_Years
FROM Fact_Sales f
JOIN Dim_Platforms p ON f.Platform_ID = p.Platform_ID
JOIN Dim_Date d ON f.Year_ID = d.Year_ID
GROUP BY p.Platform
ORDER BY Lifespan_Years DESC;


-- 2 Regional Sales Contribution Query 
SELECT g.Name, 
       SUM(f.Global_Sales) as Total_Global_Sales_Millions,
       SUM(f.NA_Sales) as NA_Sales_Millions,
       SUM(f.EU_Sales) as EU_Sales_Millions,
       SUM(f.JP_Sales) as JP_Sales_Millions
FROM Fact_Sales f
JOIN Dim_Games g ON f.Game_ID = g.Game_ID
GROUP BY g.Name
HAVING SUM(f.Global_Sales) > 0
ORDER BY Total_Global_Sales_Millions DESC;



-- 1. Calculate total global sales and total number of unique games released.

SELECT
    SUM(Global_Sales) AS Total_Global_Sales,
    COUNT(DISTINCT Game_ID) AS Total_Games
FROM Fact_Sales;
-- 2. Analyze global sales performance across different decades.

SELECT
    D.Decade,
    SUM(F.Global_Sales) AS Total_Sales
FROM Fact_Sales F
JOIN Dim_Date D
ON F.Year_ID = D.Year_ID
GROUP BY D.Decade
ORDER BY Total_Sales DESC;
-- 3. Calculate the percentage of games that sold more than one million copies.

SELECT
(
    CAST(
        COUNT(CASE WHEN Million_Seller='Yes' THEN 1 END)
        AS FLOAT
    )
    /
    COUNT(*)
) * 100 AS Million_Seller_Percentage
FROM Dim_Games;
-- 4.Rank manufacturers based on total global sales.

SELECT

    Manufacturer,
    Total_Sales,

    RANK() OVER(ORDER BY Total_Sales DESC) AS Sales_Rank

FROM
(
    SELECT

        P.Manufacturer,

        SUM(F.Global_Sales) AS Total_Sales

    FROM Fact_Sales F

    JOIN Dim_Platforms P

    ON F.Platform_ID=P.Platform_ID

    GROUP BY P.Manufacturer

) X;
--5. Rank gaming platforms based on total global sales.

SELECT *

FROM
(
    SELECT

        P.Platform,

        SUM(F.Global_Sales) AS Total_Sales,

        DENSE_RANK()

        OVER

        (
            ORDER BY SUM(F.Global_Sales) DESC
        )

        AS Platform_Rank

    FROM Fact_Sales F

    JOIN Dim_Platforms P

    ON F.Platform_ID=P.Platform_ID

    GROUP BY P.Platform

) X

WHERE Platform_Rank <=5;
-- 6. Determine which gaming platforms had the longest lifespan in the market.

SELECT
    P.Platform,
    MIN(D.Year) AS First_Year,
    MAX(D.Year) AS Last_Year,
    MAX(D.Year)-MIN(D.Year) AS Lifespan
FROM Fact_Sales F
JOIN Dim_Platforms P
ON F.Platform_ID=P.Platform_ID
JOIN Dim_Date D
ON F.Year_ID=D.Year_ID
GROUP BY P.Platform
ORDER BY Lifespan DESC;
-- 7. Compare total sales across major regions (North America, Europe, and Japan).

SELECT
    SUM(NA_Sales) AS North_America,
    SUM(EU_Sales) AS Europe,
    SUM(JP_Sales) AS Japan
FROM Fact_Sales;
-- 8. Identify the most popular game genre in each region.

-- North America

SELECT TOP 1
    G.Genre,
    SUM(F.NA_Sales) AS Sales
FROM Fact_Sales F
JOIN Dim_Games G
ON F.Game_ID=G.Game_ID
GROUP BY G.Genre
ORDER BY Sales DESC;
-- Europe

SELECT TOP 1
    G.Genre,
    SUM(F.EU_Sales) AS Sales
FROM Fact_Sales F
JOIN Dim_Games G
ON F.Game_ID=G.Game_ID
GROUP BY G.Genre
ORDER BY Sales DESC;
-- Japan

SELECT TOP 1
    G.Genre,
    SUM(F.JP_Sales) AS Sales
FROM Fact_Sales F
JOIN Dim_Games G
ON F.Game_ID=G.Game_ID
GROUP BY G.Genre
ORDER BY Sales DESC;
-- 9. List games that achieved sales across all regions worldwide.

SELECT
    G.Name,
    F.Global_Sales
FROM Fact_Sales F
JOIN Dim_Games G
ON F.Game_ID=G.Game_ID
WHERE
    F.NA_Sales>0
    AND F.EU_Sales>0
    AND F.JP_Sales>0
    AND F.Other_Sales>0
ORDER BY F.Global_Sales DESC;
-- 10. Identify the top 5 publishers based on total global sales.

SELECT TOP 5
    P.Publisher,
    SUM(F.Global_Sales) AS Total_Sales
FROM Fact_Sales F
JOIN Dim_Publishers P
ON F.Publisher_ID=P.Publisher_ID
GROUP BY P.Publisher
ORDER BY Total_Sales DESC;
-- 11. Determine the publisher with the highest number of million-selling games.

SELECT TOP 1
    P.Publisher,
    COUNT(*) AS Million_Sellers
FROM Fact_Sales F
JOIN Dim_Games G
ON F.Game_ID=G.Game_ID
JOIN Dim_Publishers P
ON F.Publisher_ID=P.Publisher_ID
WHERE G.Million_Seller='Yes'
GROUP BY P.Publisher
ORDER BY Million_Sellers DESC;
-- 12.Retrieve the top-selling game in each genre.

SELECT *

FROM
(
    SELECT

        G.Genre,

        G.Name,

        F.Global_Sales,

        ROW_NUMBER()

        OVER
        (
            PARTITION BY G.Genre

            ORDER BY F.Global_Sales DESC
        )

        AS Row_Num

    FROM Fact_Sales F

    JOIN Dim_Games G

    ON F.Game_ID=G.Game_ID

) X

WHERE Row_Num=1;
