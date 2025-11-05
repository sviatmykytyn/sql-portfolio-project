-- CTE 1: Account metrics
WITH accounts_metrics AS (
  SELECT s.date,
         sp.country,
         send_interval,
         is_verified,
         is_unsubscribed,
         COUNT(a.id) AS account_cnt
  FROM `DA.account_session` acs
  JOIN `DA.session` s
    ON acs.ga_session_id = s.ga_session_id
  JOIN `DA.account` a
    ON a.id = acs.account_id
  JOIN `DA.session_params` sp
    ON sp.ga_session_id = acs.ga_session_id
  GROUP BY 1, 2, 3, 4, 5
),

-- CTE 2: Email metrics
email_metrics AS (
  SELECT DATE_ADD(s.date, INTERVAL send_interval DAY) AS date,
         sp.country,
         send_interval,
         is_verified,
         is_unsubscribed,
         COUNT(DISTINCT es.id_message) AS emails_sent,
         COUNT(DISTINCT eo.id_message) AS emails_open,
         COUNT(DISTINCT ev.id_message) AS emails_visit
  FROM `DA.email_sent` es
  JOIN `DA.account_session` acs
    ON acs.account_id = es.id_account
  JOIN `DA.session` s
    ON s.ga_session_id = acs.ga_session_id
  JOIN `DA.session_params` sp
    ON sp.ga_session_id = acs.ga_session_id
  JOIN `DA.account` a
    ON a.id = acs.account_id
  LEFT JOIN `DA.email_open` eo
    ON es.id_message = eo.id_message
  LEFT JOIN `DA.email_visit` ev
    ON ev.id_message = es.id_message
  GROUP BY 1, 2, 3, 4, 5
),

-- CTE 3: Merge account and email metrics
total_metrics AS (
  SELECT date,
         country,
         send_interval,
         is_verified,
         is_unsubscribed,
         account_cnt,
         0 AS emails_sent,
         0 AS emails_open,
         0 AS emails_visit
  FROM accounts_metrics
  UNION ALL
  SELECT date,
         country,
         send_interval,
         is_verified,
         is_unsubscribed,
         0 AS account_cnt,
         emails_sent,
         emails_open,
         emails_visit
  FROM email_metrics
),

-- CTE 4: Group total metrics
group_total_metrics AS (
  SELECT date, 
         country, 
         send_interval, 
         is_verified, 
         is_unsubscribed,
         SUM(account_cnt) AS account_cnt,
         SUM(emails_sent) AS emails_sent,
         SUM(emails_open) AS emails_open,
         SUM(emails_visit) AS emails_visit
  FROM total_metrics
  GROUP BY 1, 2, 3, 4, 5
),

-- CTE 5: Calculate metrics per country
add_metrics AS (
  SELECT date, 
         country, 
         send_interval, 
         is_verified, 
         is_unsubscribed,
         account_cnt, 
         emails_sent, 
         emails_open, 
         emails_visit,
         SUM(account_cnt) OVER (PARTITION BY country) AS total_country_account_cnt,
         SUM(emails_sent) OVER (PARTITION BY country) AS total_country_sent_cnt
  FROM group_total_metrics
),

-- CTE 6: Rank countries by metrics
add_metrics_1 AS (
  SELECT date, 
         country, 
         send_interval, 
         is_verified, 
         is_unsubscribed,
         account_cnt,
         emails_sent AS sent_msg,
         emails_open AS open_msg,
         emails_visit AS visit_msg,
         total_country_account_cnt,
         total_country_sent_cnt,
         DENSE_RANK() OVER (ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
         DENSE_RANK() OVER (ORDER BY total_country_sent_cnt DESC) AS rank_total_country_sent_cnt
  FROM add_metrics
)

SELECT *
FROM add_metrics_1
WHERE rank_total_country_account_cnt <= 10 OR rank_total_country_sent_cnt <= 10;
