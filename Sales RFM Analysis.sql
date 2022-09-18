--Inspecting data
SELECT * FROM [dbo].[sales_data_sample$]

--Checking unique values
select distinct status from [dbo].[sales_data_sample$] 
select distinct year_id from [dbo].[sales_data_sample$] 
select distinct PRODUCTLINE from [dbo].[sales_data_sample$] 
select distinct COUNTRY from [dbo].[sales_data_sample$] 
select distinct DEALSIZE from [dbo].[sales_data_sample$] 
select distinct TERRITORY from [dbo].[sales_data_sample$]  

--ANALYSIS
--Let's start by grouping sales by productline
SELECT productline, SUM (sales) Revenue
FROM [dbo].[sales_data_sample$] 
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

SELECT year_id, SUM (sales) Revenue
FROM [dbo].[sales_data_sample$] 
GROUP BY YEAR_ID
ORDER BY 2 DESC

SELECT DEALSIZE, SUM (sales) Revenue
FROM [dbo].[sales_data_sample$] 
GROUP BY DEALSIZE
ORDER BY 2 DESC

--what was the best month for sales in a specific year? how much was earned that month?

SELECT MONTH_ID, SUM (sales) Revenue, COUNT (ORDERNUMBER) Frequency
FROM [dbo].[sales_data_sample$] 
WHERE YEAR_ID = 2003
GROUP BY MONTH_ID
ORDER BY 2 desc

--November seems to be the month. What product do they sell in November?

SELECT MONTH_ID, PRODUCTLINE, SUM (sales) Revenue, COUNT (ORDERNUMBER) Frequency
FROM [dbo].[sales_data_sample$] 
WHERE YEAR_ID = 2003 AND MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 desc

--Who is our best customer? -- RFM Analysis

	WITH RFM AS
	(
	SELECT CUSTOMERNAME,
	SUM (sales) MonetaryValue,
	AVG (sales) AvgMonetaryValue,
	COUNT (ORDERNUMBER) Frequency,
	MAX (ORDERDATE) last_order_date,
	(SELECT MAX (ORDERDATE) FROM [dbo].[sales_data_sample$] ) max_order_date,
	DATEDIFF(DD, MAX (ORDERDATE), (SELECT MAX (ORDERDATE) FROM [dbo].[sales_data_sample$])) Recency
	FROM [dbo].[sales_data_sample$] 
	GROUP BY CUSTOMERNAME
	),
	rfm_calc AS
	(
	SELECT r.*,
	NTILE(4) OVER (order by Recency desc) rfm_recency,
	NTILE (4) OVER (order by Frequency) rfm_frequency,
	NTILE (4) OVER (order by AvgMonetaryValue) rfm_monetary
	FROM rfm r
	)
	SELECT c.*, rfm_recency + rfm_frequency + rfm_monetary	as rfm_cell,
	CAST (rfm_recency AS varchar) + CAST (rfm_frequency AS varchar) + CAST (rfm_monetary AS varchar)rfm_cell_string
	FROM rfm_calc c

	DROP TABLE IF EXISTS #rfm
;with rfm as 
(
	select 
		CUSTOMERNAME, 
		sum(sales) MonetaryValue,
		avg(sales) AvgMonetaryValue,
		count(ORDERNUMBER) Frequency,
		max(ORDERDATE) last_order_date,
		(select max(ORDERDATE) from [dbo].[sales_data_sample$]) max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data_sample$] )) Recency
	from [dbo].[sales_data_sample$] 
	group by CUSTOMERNAME
),
rfm_calc as
(

	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency) rfm_frequency,
		NTILE(4) OVER (order by MonetaryValue) rfm_monetary
	from rfm r
)
select 
	c.*, rfm_recency+ rfm_frequency+ rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary  as varchar)rfm_cell_string
into #rfm
from rfm_calc c

select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment

from #rfm

--What products are most often sold together?

select distinct OrderNumber, stuff(

	(select ',' + PRODUCTCODE
	from [dbo].[sales_data_sample$] p
	where ORDERNUMBER in 
		(

			select ORDERNUMBER
			from (
				select ORDERNUMBER, count(*) rn
				FROM [dbo].[sales_data_sample$]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path (''))

		, 1, 1, '') ProductCodes

from [dbo].[sales_data_sample$] s
order by 2 desc
