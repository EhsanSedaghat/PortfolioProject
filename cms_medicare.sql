--Total drugs prescribed by each state

SELECT SUM(total_claim_count) as total_drug_prescribed, nppes_provider_state
FROM `bigquery-public-data.cms_medicare.part_d_prescriber_2014`
GROUP BY nppes_provider_state
ORDER BY total_drug_prescribed DESC;

-- Most prescribed medication in each state

SELECT X.state, drug_name, max_total
FROM (
    SELECT 
        SUM(total_claim_count) as total, drug_name, nppes_provider_state AS state
    FROM `bigquery-public-data.cms_medicare.part_d_prescriber_2014`
    GROUP BY drug_name ,state) as X
INNER JOIN (
    SELECT 
        state, MAX(total) AS max_total 
    FROM (SELECT nppes_provider_state AS state, SUM(total_claim_count) as total 
    FROM `bigquery-public-data.cms_medicare.part_d_prescriber_2014`
    GROUP BY drug_name, state) GROUP BY state ) AS Y
ON X.state = Y.state AND X.total = Y.max_total
GROUP BY X.state, drug_name, max_total 
ORDER BY max_total DESC;

-- Average cost for inpatient and outpatient treatment in each city and state

SELECT 
    outpatient.provider_state AS State,
    outpatient.provider_city AS City,
    outpatient.provider_id AS Provider_ID,
    outpatient.avg_outpatient_cost,
    inpatient.avg_inpatient_cost,
    ROUND(inpatient.avg_inpatient_cost + outpatient.avg_outpatient_cost) AS total_average_cost
FROM
(SELECT
    provider_state,
    provider_city,
    provider_id,
    ROUND(SUM(average_total_payments*outpatient_services)/SUM(outpatient_services)) AS avg_outpatient_cost
    FROM `bigquery-public-data.cms_medicare.outpatient_charges_2014`
    GROUP BY 
        provider_state, 
        provider_city,
        provider_id) AS outpatient 
INNER JOIN 
(SELECT
    provider_state,
    provider_city,
    provider_id,
    ROUND(SUM(average_medicare_payments*total_discharges)/SUM(total_discharges)) AS avg_inpatient_cost
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2014`
    GROUP BY 
        provider_state, 
        provider_city,
        provider_id) AS inpatient 

ON 
    outpatient.provider_id = inpatient.provider_id
    AND outpatient.provider_state = inpatient.provider_state
    AND outpatient.provider_city = inpatient.provider_city
ORDER BY state, city

-- most common inpatient diagnostic conditions in the U.S

SELECT 
    drg_definition, 
    COUNT(drg_definition) AS total_diagnosis
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2014`
GROUP BY drg_definition
ORDER BY total_diagnosis DESC
limit 5

-- Top 3 rank cities with the most diagnostic conditions in the U.S and comparing their average cost national

SELECT 
    diagnostic_condition,
    city,
    state,
    city_rank,
    CONCAT('$', CAST(city_avg_total_payments AS INT)) AS city_avg_payments,
    CONCAT(ROUND(city_avg_total_payments/(national_sum_total_payments/national_num_cases)*100,0), " %") AS city_vs_national_payments
FROM 
(
SELECT 
    diagnostic_condition,
    city,
    state,
    city_sum_total_payments,
    city_avg_total_payments,
    RANK() OVER(PARTITION BY diagnostic_condition ORDER BY city_num_cases DESC) AS city_rank,
    SUM(city_num_cases) OVER(PARTITION BY diagnostic_condition) AS national_num_cases,
    ROUND(SUM(city_sum_total_payments) OVER(PARTITION BY diagnostic_condition),2) AS national_sum_total_payments
FROM 
(
    SELECT 
        drg_definition AS diagnostic_condition,
        provider_city AS city,
        provider_state AS state,
        SUM(total_discharges) AS city_num_cases,
        ROUND(SUM(average_total_payments * total_discharges)/SUM(total_discharges),
        2) AS city_avg_total_payments,
        SUM(average_total_payments * total_discharges) AS city_sum_total_payments
    FROM 
        `bigquery-public-data.medicare.inpatient_charges_2014`
    GROUP BY 
        diagnostic_condition,
        city,
        state
    ))
    WHERE 
        city_rank <= 3
    ORDER BY 
        national_num_cases DESC,
        city_rank
    LIMIT 9;
