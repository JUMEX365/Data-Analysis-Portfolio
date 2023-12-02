-- By Литвинов Артем


/* 1) Вывести список сотрудников, получающих заработную плату большую чем у непосредственного руководителя*/

WITH CTE1 AS (
	SELECT ID, NAME, SALARY, CHEF_ID, COPY.SALARY AS CHEF_SALARY
	FROM DB.EMPLOYEE
	LEFT JOIN DB.EMPLOYEE COPY
	ON DB.EMPLOYEE.CHEF_ID = COPY.ID
	)
SELECT ID, NAME
FROM CTE1
WHERE SALARY > CHEF_SALARY; 



/* 2) Вывести список сотрудников, получающих максимальную заработную плату в своем отделе*/

WITH CTE2 AS (
	SELECT ID, NAME, SALARY, DEPARTMENT_ID, MAX(SALARY) OVER (PARTITION BY DEPARTMENT_ID) AS MAXSLR
	FROM DB.EMPLOYEE
	)
Select ID, NAME -- CTE используем чтобы избежать ошибки в 'WHERE'
FROM CTE2
WHERE SALARY = MAXSLR; 



/* 3) Вывести список ID отделов, количество сотрудников в которых не превышает 3 человек*/

WITH CTE3 AS (
	SELECT ID, NAME, SALARY, DEPARTMENT_ID, COUNT(ID) OVER (PARTITION BY DEPARTMENT_ID) AS N_EMPL
	FROM DB.EMPLOYEE
	)
SELECT DISTINCT DEPARTMENT_ID
FROM CTE3
WHERE N_EMPL <= 3;



/* 4) Вывести список сотрудников, не имеющих назначенного руководителя, работающего в том же отделе*/

WITH CTE4 AS(
	SELECT ID, NAME, DEPARTMENT_ID, CHEF_ID, COPY1.DEPARTMENT_ID AS CHEF_DEP_ID
	FROM DB.EMPLOYEE
	LEFT JOIN DB.EMPLOYEE COPY1
	ON DB.EMPLOYEE.CHEF_ID = COPY1.ID
	)
SELECT ID, NAME
FROM CTE4
WHERE DEPARTMENT_ID <> CHEF_DEP_ID;



/* 5) Найти список ID отделов с максимальной суммарной зарплатой сотрудников*/

--Будем считать, что сумма ЗП в некоторых отделах может быть равна. 
--Значит, отделов с максимальной ЗП может быть несколько. Выведем их все:

WITH CTE5 (
	SELECT ID, SALARY, DEPARTMENT_ID, SUM(SALARY) OVER (PARTITION BY DEPARTMENT ID) AS SAL_SUM
	FROM DB.EMPLOYEE
	),
CTE6 AS (
	SELECT DISTINCT DEPARTMENT_ID, SAL_SUM, DENSE_RANK() OVER (ORDER BY SAL_SUM DESC) AS RNK
	FROM CTE5
	)
SELECT DEPARTMENT_ID
FROM CTE6
WHERE RNK = 1;































