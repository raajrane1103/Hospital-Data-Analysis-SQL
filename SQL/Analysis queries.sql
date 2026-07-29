use hospital_db;

SELECT *
FROM Encounters e
JOIN Patients p
    ON e.Patient = p.Id
JOIN Organizations o
    ON e.Organizations = o.Id
JOIN Payers pay
    ON e.Payer = pay.Id
JOIN Procedures pr
    ON e.Id = pr.Encounter
    AND e.Patient = pr.Patient
    limit 10;
 


 -- 1 Total Number of Patients --
SELECT COUNT(ID) AS Total_Patients
FROM Patients;


-- 2 Gender Distribution --
SELECT Gender, COUNT(*) AS Total_Patients
FROM Patients
GROUP BY Gender
ORDER BY Total_Patients DESC;


-- 3 Patient Age Groups --
SELECT CASE
  WHEN TIMESTAMPDIFF(YEAR, Full_Birth_Date, CURDATE()) < 18 THEN 'Child'
  WHEN TIMESTAMPDIFF(YEAR, Full_Birth_Date, CURDATE()) BETWEEN 18 AND 39 THEN 'Young Adult'
  WHEN TIMESTAMPDIFF(YEAR, Full_Birth_Date, CURDATE()) BETWEEN 40 AND 64 THEN 'Adult'
  ELSE 'Senior'
END AS Age_Group, COUNT(*) AS Patient_Count
FROM Patients
GROUP BY Age_Group
ORDER BY Patient_Count DESC;


-- 4 City_Wise Patient Count --
 SELECT Residential_City AS City, COUNT(*) AS Patients
FROM Patients
GROUP BY City
ORDER BY Patients DESC;


-- 5 Encounters Per Year --
SELECT Start_Year, COUNT(*) AS Total_Encounters
FROM Encounters
GROUP BY Start_Year
ORDER BY Start_Year ASC;


-- 6 Encounter Class Distribution -- 
SELECT Encounter_Class, COUNT(*) AS Total_Count
FROM Encounters
GROUP BY Encounter_Class
ORDER BY Total_Count DESC;


-- 7 Average Claim Cost Across Encounter Class --
SELECT Encounter_Class, ROUND(AVG(Total_Claim_Cost),2) AS Average_Claim
FROM Encounters
GROUP BY Encounter_Class
ORDER BY Average_Claim DESC;


-- 8 Insurance Coverage Percetage By Encounter Class --
SELECT Encounter_Class, ROUND(AVG((Payer_Coverage / Total_Claim_Cost) * 100),2) AS Avg_Coverage_Percentage 
FROM Encounters
WHERE Total_Claim_Cost > 0
GROUP BY Encounter_Class
ORDER BY Avg_Coverage_Percentage DESC;


-- 9 Patients With Most Frequent Visits -- 
SELECT p.Cleaned_First_Name AS First_Name, p.Cleaned_Last_Name AS Last_Name, COUNT(e.Id) AS Visits
FROM Patients p
INNER JOIN Encounters e
ON p.Id = e.Patient
GROUP BY p.Id, p.Cleaned_First_Name, p.Cleaned_Last_Name
ORDER BY Visits DESC
LIMIT 10;


-- 10 Patients Paying The Most Out Of Their Pockets --
SELECT p.Cleaned_First_Name AS First_Name, p.Cleaned_Last_Name AS Last_Name, ROUND(SUM(e.Total_Claim_Cost),2) AS Lifetime_Cost,
       ROUND(SUM(e.Payer_Coverage),2) AS Insurance_Paid, ROUND(SUM(e.Total_Claim_Cost - e.Payer_Coverage),2) AS Out_Of_Pocket
FROM Patients p
JOIN Encounters e
ON p.Id = e.Patient
GROUP BY p.Id, p.Cleaned_First_Name, p.Cleaned_Last_Name
ORDER BY Out_Of_Pocket DESC
LIMIT 10;


-- 11 Highest Bill Coverage By Insurance By Percentage --
SELECT Concat(p.Cleaned_First_Name, ' ' , p.Cleaned_Last_Name) AS Full_Name, ROUND(SUM(e.Total_Claim_Cost),2) AS Total_Cost,
       ROUND(SUM(e.Payer_Coverage),2) AS Insurance_Paid, ROUND((SUM(e.Payer_Coverage) / SUM(e.Total_Claim_Cost)) * 100, 2) 
       AS Coverage_Percentage
FROM Patients p
JOIN Encounters e
ON p.Id = e.Patient
GROUP BY p.Id, p.First_Name, p.Last_Name
HAVING SUM(e.Total_Claim_Cost) > 0
ORDER BY Coverage_Percentage DESC;


-- 12 Most Frequently Performed Procedures --
SELECT Description, COUNT(*) AS Times_Performed
FROM Procedures
GROUP BY Description
ORDER BY Times_Performed DESC
LIMIT 10;


-- 13 Most Common Medical Conditions Requiring Procedures --
SELECT Reason_Description, COUNT(*) AS Total
FROM Procedures
WHERE Reason_Description IS NOT NULL
GROUP BY Reason_Description
ORDER BY Total DESC
LIMIT 10;


-- 14 Patients With No Recorded Procedures --
SELECT p.Cleaned_First_Name AS First_Name, p.Cleaned_Last_Name AS Last_Name
FROM Patients p
LEFT JOIN Procedures pr
ON p.Id = pr.Patient
WHERE pr.Patient IS NULL;


-- 15 Patients Who Underwent Most Procedures -- 
SELECT p.Cleaned_First_Name AS Firsts_Name, p.Cleaned_Last_Name AS Last_Name, COUNT(pr.Procedure_ID) AS Procedures
FROM Patients p
INNER JOIN Procedures pr
ON p.Id = pr.Patient
GROUP BY p.Id, p.First_Name, p.Last_Name
ORDER BY Procedures DESC
LIMIT 10;


-- 16 Encounter Categorized by Claim Amount --
SELECT Id, Total_Claim_Cost,
  CASE
    WHEN Total_Claim_Cost < 1000 THEN 'Low Cost'
	WHEN Total_Claim_Cost BETWEEN 1000 AND 5000 THEN 'Medium Cost'
	ELSE 'High Cost'
END AS Cost_Category
FROM Encounters;


-- 17 Top Patients By Insurance Claim Cost Each Year --
WITH PatientYearCost AS (
SELECT e.Start_Year, p.Cleaned_First_Name AS First_Name, p.Cleaned_Last_Name AS Last_Name, SUM(e.Total_Claim_Cost) AS Total_Cost,
	   ROW_NUMBER() OVER (PARTITION BY e.Start_Year ORDER BY SUM(e.Total_Claim_Cost) DESC) AS Ranked
    FROM Patients p
    INNER JOIN Encounters e
        ON p.Id = e.Patient
    GROUP BY e.Start_Year, p.Id, p.First_Name, p.Last_Name
)
SELECT *
FROM PatientYearCost
WHERE Ranked = 1;


-- 18 Insurance Providers Ranked By Total Coverage --
SELECT py.Name, ROUND(SUM(e.Payer_Coverage),2) AS Total_Covered, 
       DENSE_RANK() OVER (ORDER BY SUM(e.Payer_Coverage) DESC) AS Coverage_Rank
FROM Encounters e
JOIN Payers py
ON e.Payer = py.Id
GROUP BY py.Id, py.Name;


-- 19 Patients Whose Lifetime Cost Is Above Hospital Average --
WITH PatientCosts AS (
  SELECT p.Id, p.Cleaned_First_Name AS First_Name, p.Cleaned_Last_Name AS Last_Name, SUM(e.Total_Claim_Cost) AS Lifetime_Cost
  FROM Patients p
  JOIN Encounters e
  ON p.Id = e.Patient
  GROUP BY p.Id, p.First_Name, p.Last_Name
)
SELECT *, row_number() OVER (Order by Lifetime_Cost DESC) AS Ranked
FROM PatientCosts
WHERE Lifetime_Cost >  ( SELECT AVG(Lifetime_Cost) FROM PatientCosts)
Limit 15;


-- 20 Which Encounter Classes Have Above Average Claim Cost --
SELECT Encounter_Class, ROUND(AVG(Total_Claim_Cost),2) AS Average_Claim,
       RANK() OVER (ORDER BY ROUND(AVG(Total_Claim_Cost),2) DESC) AS Ranked
FROM Encounters
GROUP BY Encounter_Class
HAVING AVG(Total_Claim_Cost) > (SELECT AVG(Total_Claim_Cost) FROM Encounters)
ORDER BY Average_Claim DESC;


-- 21 Encounter Classes By Total Revenue --
SELECT Encounter_Class, ROUND(SUM(Total_Claim_Cost),2) AS Total_Revenue,
       DENSE_RANK() OVER (ORDER BY SUM(Total_Claim_Cost) DESC) AS Revenue_Rank
FROM Encounters
GROUP BY Encounter_Class;


-- 22 Which Insurance Provider Have Above Average Insurance Coverage --
WITH PayerCoverage AS (
  SELECT Payer, SUM(Payer_Coverage) AS Total_Coverage
  FROM Encounters
  GROUP BY Payer
)
SELECT py.Name, ROUND(pc.Total_Coverage, 2) AS Total_Coverage
FROM PayerCoverage pc
INNER JOIN Payers py
ON pc.Payer = py.Id
WHERE pc.Total_Coverage > (SELECT AVG(Total_Coverage) FROM PayerCoverage)
ORDER BY Total_Coverage DESC;


