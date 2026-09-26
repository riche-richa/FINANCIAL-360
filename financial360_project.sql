use finance_db;

describe credit_score;
describe defaulters;

set sql_safe_updates = 1;

update credit_score
set customer_id = 1000+
cast(substring(customer_id,2) as unsigned);

update defaulters
set customer_id = 1000 +
cast(substring(customer_id,2) as unsigned);

select distinct customer_id
from credit_score
order by customer_id
limit 10;
select count(*) as customers_count from customers;
select count(*) as accounts_count from accounts;
select count(*) as banks_count from banks;
select count(*) as creditcards_count from creditcards;
select count(*) as loans_count from f_m_loans;
select count(*) as transactions_count from transactions;  
select count(*) from credit_score;
select count(*) from defaulters;
select * from credit_score limit 10;
select* from defaulters limit 10;

select 'customers' as table_name, count(*) as row_count from customers
union all
select 'accounts', count(*) from accounts
union all
select 'banks', count(*) from banks
union all
select 'creditcards', count(*) from creditcards
union all
select 'loans', count(*) from f_m_loans
union all
select 'transactions', count(*) from transactions;

describe customers;

alter table credit_score
modify customer_id int;
alter table credit_score
add primary key (record_id);
alter table credit_score
add constraint fk_credit_score_customer
foreign key (customer_id)
references customers(customer_id);

alter table defaulters
modify customer_id  int;
alter table defaulters
add constraint fk_deefaulters_customer
foreign key (customer_id)
references customers(customer_id);


-- ====================================================
-- FINANCIAL 360
-- QUERY 1: CUSTOMER FINANCIAL FOOTPRINT
-- ====================================================
-- Business Question:
-- Which customers holds multiple financial products and show 
-- significant transaction activity?
-- =====================================================

with account_summary as (
select a.customer_id, count(distinct a.account_id) as total_accounts,
coalesce(sum(a.balance),0) as total_account_balance
from accounts a
group by a.customer_id),


transaction_summary as(
select a.customer_id, count(distinct t.txn_id) as total_transactions,
coalesce(sum(t.amount),0) as total_transaction_value
from accounts a
join transactions t
on a.account_id = t.account_id
group by a.customer_id
),

card_summary as(
select customer_id, count(distinct card_id) as total_credit_cards,
coalesce(sum(outstanding),0) as total_card_outstanding
from creditcards
group by customer_id
),

loan_summary as(
select l.customer_id, count(distinct l.loan_id) as total_loans,
coalesce(sum(l.amount),0) as total_loan_amount
from f_m_loans l
group by customer_id )

select
c.customer_id,
c.name,
c.pan_code,
c.aadhaar_code,
coalesce(a.total_accounts,0) as total_accounts,
coalesce(a.total_account_balance,0) as total_account_balance,
coalesce(t.total_transaction_value,0) as total_transaction_value,
coalesce(cc.total_credit_cards,0) as total_credit_cards,
coalesce(cc.total_card_outstanding,0) as total_card_outstanding,
coalesce(l.total_loans,0) as total_loans,
coalesce(l.total_loan_amount,0) as total_loan_amount

from customers c
left join account_summary a 
on c.customer_id = a.customer_id

left join transaction_summary t
on c.customer_id = t.customer_id

left join card_summary cc
on c.customer_id = cc.customer_id

left join loan_summary l
on c.customer_id = l.customer_id

order by total_transaction_value desc;

select * from accounts limit 5;

describe transactions;
describe banks;
describe f_m_loans;

-- ================================================
-- query 2: MAJOR CUSTOMER TRANSACTION BY BANK
-- ================================================
-- BUSINESS QUESTION : WHAT IS THE LARGEST TRANSACTION MADE BY EACH CUSTOMER
-- AND THROUGH WHICH BANK WAS IT MADE?
-- SQL CONCEPTS : INNER JOIN, CTE, ROW_NUMBER(), PARTITION BY, ORDER BY, FILTERING
-- =================================================
with ranked_transactions as(
select t.txn_id, t.account_id,a.customer_id,c.name, a.bank_id,b.bank_name, t.amount,
row_number() over(
partition by a.customer_id
order by t.amount desc
)as transaction_rank 
from transactions t
join accounts a 
on t.account_id = a.account_id
join banks b
on a.bank_id = b.bank_id
join customers c 
on c.customer_id = a.customer_id)
select customer_id, name, bank_name, amount
from ranked_transactions
where transaction_rank = 1
order by amount desc;


select a.customer_id, c.name, count(*) as transaction_count
from transactions t
join accounts a 
on t.account_id = a.account_id
join customers c 
on c.customer_id = a.customer_id
group by  a.customer_id,c.name
order by a.customer_id;

-- ===========================================
-- QUERY 3: LOANS ISSUED BY BANK AND LOAN TYPE
-- ===========================================
-- BUSINESS QUESTION: WHICH BANKS HAVE ISSUED MAXIMUM LOANS AND WHAT LOAN TYPE
-- CONTRIBUTING TO TOTAL LOANS AMOUNT
-- SQL CONCEPTS: INNER JOIN, GROUP BY ,COUNT, SUM, COALESCE, ORDER BY
-- ==============================================

select b.bank_name, l.loan_type, count(distinct l.loan_id) as total_loans,
coalesce(sum(l.amount),0) as total_loan_amount
from f_m_loans l 
join banks b
on l.bank_id= b.bank_id
group by b.bank_id, b.bank_name,l.loan_type
order by total_loan_amount desc;


SELECT b.bank_name,l.status, count(distinct loan_id) as total_loans,
coalesce(sum(amount),0) as total_loan_amount
from f_m_loans l 
join banks b
on l.bank_id = b.bank_id
group by b.bank_id, b.bank_name, l.status
order by total_loan_amount desc;

-- ===============================================
-- QUERY 4: CUSTOMER CREDIT SCORE TREND
-- ===============================================
-- BUSINESS QUESTION: ANALYSE CUSTOMER CREDIT-SCORE MOVEMENT OVER TIME USING
-- THE LAG WINDOW FUNCTION  TO IDENTIFY IMPROVEMENTS AND DETORIATIONS IN CREDITWORTHINESS
-- ===============================================
with score_history as(
select customer_id, event_date,credit_score,
lag(credit_score) over(
partition by customer_id
order by event_date
)as previous_score
from credit_score
)
select customer_id, event_date, credit_score, previous_score, credit_score - previous_score as score_change
from score_history
where previous_score is not null
order by score_change desc;

-- ==============================================
-- QUERY 5: CUSTOMER DEFAULT RISK AND EXPOSURE
-- ===============================================

with customer_defaults as(
select customer_id, product_type, count(*) as default_count, sum(overdue_amount) as total_overdue
from defaulters
group by customer_id, product_type
)
select customer_id, product_type, default_count, total_overdue,
rank() over(
order by total_overdue desc
)as exposure_rank
from customer_defaults
order by exposure_rank;

-- =============================================
-- QUERY 6: IDENTIFY THE CUSTOMER WHO MADE THE HIGHEST-VALUE TRANSACTION
-- AND SHOW THE TRANSACTION DETAILS
-- =============================================

with maximum_transaction as(
     select max(amount) as max_amount
     from transactions 
     )
     select c.customer_id, c.name, c.pan_code, c.aadhaar_code,t.txn_id, t.account_id, t.amount
     from transactions t
     join maximum_transaction m
     on t.amount = max_amount
     join accounts a 
     on t.account_id = a.account_id
     join customers c 
     on a.customer_id = c.customer_id;
     
     
     -- =========================================
     -- QUERY 7: FOR EVERY CUSTOMER FIND HIGHST VALUE TRANSACTION
     -- RANK THEM FROM HIGEST TO LOWEST
     -- =========================================
     
     with maximum_transaction as (
     select a.customer_id, max(t.amount) as max_customer_amount
     from accounts a
     join transactions t
     on a.account_id = t.account_id
     group by a.customer_id 
     )
     
	 select c.customer_id, c.name, c.pan_code, c.aadhaar_code, m.max_customer_amount,
     
     rank() over( 
      order by max_customer_amount desc
      )as transaction_rank
      from customers c
     join maximum_transaction m
     on c.customer_id = m.customer_id
      ;
      
      -- ==============================================
      -- QUERY 8: FIND CUSTOMERS WHO HAVE BOTH A RUNNING LOAN AND A CREDIT CARD
      -- ==============================================
      
      select customer_id 
      from customers c 
      where exists(
      select 1
      from f_m_loans l where l.customer_id = c.customer_id
      )
      and exists (
      select 1
      from creditcards cc
      where cc.customer_id = c.customer_id
      );
      
      -- ==========================================
      -- QUERY 9: FIND CUSTOMERS WHOSE LOAN AMOUNT IS HIGHER THAN
      -- AVERAGE LOAN AMOUNT
      -- ===========================================
      select customer_id, amount
      from f_m_loans
      where amount >(
      select avg(amount)
      from f_m_loans);
      
      -- ============================================================
      -- QUERY 10 - FIND CUSTOMERS WHOSE TOTAL LOAN AMOUNT IS GREATER THAN
      -- AVERAGE TOTAL LOAN AMOUNT PER CUSTOMER
      -- ============================================================
      
      with total_amount as (
       select customer_id , sum(amount) as total_loan
       from f_m_loans 
       group by customer_id
       )
       select customer_id, total_loan
       from total_amount 
	   where total_loan > (
       select avg(total_loan)
       from total_amount);
       
       -- ==========================================
       --  QUERY 11 : BANKS WITH TOTAL ACCOUNT BALANCE ABOVE AVERAGE
       -- DERIVED TABLE =WINDOW FUNCTION
       -- ==========================================
       
       select bank_id, ac_balance
       from (
       select bank_id, 
       sum(balance) as ac_balance,
       avg(sum(balance)) over() as avg_balance
       from accounts
       group by bank_id
       ) as bank_loans 
       where ac_balance > avg_balance ;

       -- =================================
       -- QUERY 12: FOR EACH CUSTOMER , DISPLAY THEIR TRANSACTION AMOUNT
       -- FROM PREVIOUS AND NEXT TRANSACTION
       -- ===============================
       select a.customer_id, t.txn_id, t.amount,
       lag(amount) over(
       partition by a.customer_id
       order by t.txn_id
       ) as previous_amount,
       lead(amount) over (
       partition by a.customer_id
       order by t.txn_id
       ) as next_amount
       from transactions t
       join accounts a
       on a.account_id = t.account_id;
       
          
 -- =========================================
 -- QUERY 13: FIND CUSTOMERS WITH MULTIPLE BANK ACCOUNTS
 -- =========================================
    
    select customer_id, count(account_no) as total_accounts
    from accounts
    group by customer_id
    having count(account_no)> 1;
    
 -- ==============================================
 -- QUERY 14: SHOW THE CUSTOMER NAMES WITH MORE THAN 1 BANK ACCOUNT
 -- ALONG WITH BANK NAMES
 -- ================================================
    
select c.customer_id, c.name, group_concat(distinct b.bank_name separator',') as banks_used,
count(distinct a.bank_id) as total_banks
from customers c
join accounts a 
on c.customer_id = a.customer_id
join banks b
on b.bank_id = a.bank_id
group by c.customer_id, c.name
having count(distinct a.bank_id)>1;

-- =======================================================
-- QUERY 15: FOR EVERY BANK, FIND THE ACCOUNT WITH HIGHEST BALANCE
-- FLOW - CTE(WITH) CREATES RANKED DATASET
-- ROW_NUMBER() NUMBERS ACCOUNTS WITHIN EACH BANK
-- PARTITION BY BANK_ID RANKING RESTARTS FOR EVERY BANK
-- ORDER BY BALANCE DESC -> HIGHEST BALANCE GETS #1
-- OUTER SELECT - DISPLAYS THE REQUIRED INFO
-- WHERE BALANCE_RANK = 1 -> KEEPS ONLY HIGHEST VALUE ACCOUNT PER BANK
-- =======================================================
 with  account_balance_perbank as(
 
 select b.bank_name, c.name, a.account_no, a.balance,
 row_number() over(
 partition by a.bank_id
 order by a.balance desc
 ) as balance_rank
 
 from accounts a 
 join customers c 
 on a.customer_id = c.customer_id
 join banks b
 on b.bank_id = a.bank_id
 )
 
 select bank_name, name, account_no, balance 
 from account_balance_perbank
 where balance_rank = 1;
 
 
 -- =========================================
 -- QUERY 16: BANKWISE ACCOUNT TYPE SUMMARY WITH
 -- SUBTOTAL AND GRANDTOTAL
 -- =========================================
 
 select 
   case 
     when grouping(b.bank_name)= 1 then 'grand total'
     else b.bank_name end as bank_name,
     
     case
       when grouping(a.type)= 1
          and grouping(b.bank_name) = 0
       then 'bank total'
       when grouping(a.type) = 1
         and grouping(b.bank_name) = 1
         then 'all accounts'
        else  a.type end as account_type,
        
        count(distinct a.customer_id) as total_customers,
        count(a.account_id) as total_accounts
       
 from accounts a 
 join banks b
 on a.bank_id = b.bank_id
 group by b.bank_name, a.type with rollup;
 
 -- ========================================
 -- QUERY 17: CUSTOMER SEGMENTATION BY ACCOUNT ACTIVITY
 -- ========================================

with customer_accounts as( 
 select customer_id, count(account_id) as total_accounts
 from accounts
 group by customer_id
 ),
 
 segmented_customers as(
 select customer_id, total_accounts,
 NTILE(4) over (
 order by total_accounts desc
 ) as segment
 
 from customer_accounts
 )
 select
 customer_id, total_accounts,
 case
    when segment = 1 then 'top 25%'
    when segment = 2 then '25 -50 %'
    when segment = 3 then '50- 75%'
    else 'bottom 25%'
    end as account_segment
    from segmented_customers;


-- ===========================================
 -- QUERY 18 : PERCENTAGE OF BANK'S TOTAL TRANSACTION WAS CONTRIBUTED
 -- BY THE GIVEN CUSTOMER
 -- ===========================================
 
 with customer_transactions as(
  select a.customer_id, sum(t.amount) as customer_total
  from accounts a 
  join transactions t
  on a.account_id = t.account_id
  group by a.customer_id
  )
  
  select customer_id, customer_total,
  round(
  customer_total/sum(customer_total) over() * 100,2
  ) as contribution_percentage
  from customer_transactions
  order by contribution_percentage desc;
 
 -- ===============================================
 -- QUERY 19: FALLBACK CUSTOMER LOOKUP 
 -- ===============================================
 
 select customer_id, pan_code, aadhaar_code
 from customers
 limit 10;
 
 DROP PROCEDURE IF EXISTS find_customer;

DELIMITER //

CREATE PROCEDURE find_customer(
    IN search_pan VARCHAR(20),
    IN search_aadhaar VARCHAR(20)
)
BEGIN

    SELECT
        customer_id,
        pan_code,
        aadhaar_code,
        CASE
            WHEN pan_code = search_pan THEN 'PAN'
            WHEN aadhaar_code = search_aadhaar THEN 'AADHAAR'
        END AS matched_by
    FROM customers
    WHERE pan_code = search_pan
       OR aadhaar_code = search_aadhaar
    ORDER BY
        CASE
            WHEN pan_code = search_pan THEN 1
            WHEN aadhaar_code = search_aadhaar THEN 2
        END
    LIMIT 1;

END //

DELIMITER ;
   
  
   call find_customer(null,'A19494');
   
   -- =======================================================
   -- QUERY 20 : DUPLICATE/SUSPICIOUS TRANSACTIONS :
   -- FIND CUSTOMERS WHO MADE THE SAME TRANSACTION ACCOUNT MULTIPLE TIMES
   -- USE PYTHON TO ANALYSE THE RESULTS
   -- ======================================================
   
   with transaction_check as
   (
   select a.customer_id, t.txn_id, t.date, t.amount,
   count(*) over (
   partition by a.customer_id,t.amount
   ) as same_amount_count
   
   from transactions t
   join accounts a 
   on a.account_id = t.account_id
   )
   
   select customer_id, txn_id, date, amount, same_amount_count
   
   from transaction_check
   where same_amount_count > 1
   
   order by customer_id, amount, date;
   
      
-- ==============================================
-- QUERY 21:Credit Risk Trajectory
-- Which customers are showing sustained deterioration in their credit profile, and which customers are recovering?
-- =====================================================


USE finance_db;

WITH RECURSIVE credit_history AS
(
    SELECT
        customer_id,
        event_date,
        event_type,
        reference_id,
        credit_score,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY event_date
        ) AS rn
    FROM credit_score
),

credit_trajectory AS
(
    -- Starting point for every customer
    SELECT
        customer_id,
        rn,
        event_date,
        event_type,
        reference_id,
        credit_score,
        credit_score AS previous_score,
        0 AS score_change,
        0 AS decline_streak
    FROM credit_history
    WHERE rn = 1

    UNION ALL

    -- Walk through each customer's history
    SELECT
        h.customer_id,
        h.rn,
        h.event_date,
        h.event_type,
        h.reference_id,
        h.credit_score,

        t.credit_score AS previous_score,

        h.credit_score - t.credit_score AS score_change,

        CASE
            WHEN h.credit_score < t.credit_score
                THEN t.decline_streak + 1
            ELSE 0
        END AS decline_streak

    FROM credit_history h
    JOIN credit_trajectory t
        ON h.customer_id = t.customer_id
       AND h.rn = t.rn + 1
)

SELECT
    customer_id,
    event_date,
    event_type,
    reference_id,
    previous_score,
    credit_score,
    score_change,
    decline_streak
FROM credit_trajectory
ORDER BY customer_id, event_date;

-- ================
-- part2
-- =====================

WITH RECURSIVE credit_history AS
(
    SELECT
        customer_id,
        event_date,
        event_type,
        reference_id,
        credit_score,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY event_date
        ) AS rn
    FROM credit_score
),

credit_trajectory AS
(
    -- Starting point for every customer
    SELECT
        customer_id,
        rn,
        event_date,
        event_type,
        reference_id,
        credit_score,
        credit_score AS previous_score,
        0 AS score_change,
        0 AS decline_streak
    FROM credit_history
    WHERE rn = 1

    UNION ALL

    -- Walk through each customer's history
    SELECT
        h.customer_id,
        h.rn,
        h.event_date,
        h.event_type,
        h.reference_id,
        h.credit_score,

        t.credit_score AS previous_score,

        h.credit_score - t.credit_score AS score_change,

        CASE
            WHEN h.credit_score < t.credit_score
                THEN t.decline_streak + 1
            ELSE 0
        END AS decline_streak

    FROM credit_history h
    JOIN credit_trajectory t
        ON h.customer_id = t.customer_id
       AND h.rn = t.rn + 1
)

SELECT
    customer_id,
    event_date,
    event_type,
    reference_id,
    previous_score,
    credit_score,
    score_change,
    decline_streak
FROM credit_trajectory
ORDER BY customer_id, event_date;

USE finance_db;

WITH RECURSIVE credit_history AS
(
    SELECT
        customer_id,
        event_date,
        event_type,
        reference_id,
        credit_score,

        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY event_date
        ) AS rn
    FROM credit_score
),

credit_trajectory AS
(
    -- Anchor: first credit event
    SELECT
        customer_id,
        rn,
        event_date,
        event_type,
        reference_id,
        credit_score,
        credit_score AS previous_score,
        0 AS score_change,
        0 AS decline_streak
    FROM credit_history
    WHERE rn = 1

    UNION ALL

    -- Recursive step: process the next event
    SELECT
        h.customer_id,
        h.rn,
        h.event_date,
        h.event_type,
        h.reference_id,
        h.credit_score,
        t.credit_score AS previous_score,

        h.credit_score - t.credit_score AS score_change,

        CASE
            WHEN h.credit_score < t.credit_score
                THEN t.decline_streak + 1
            ELSE 0
        END AS decline_streak

    FROM credit_history h
    JOIN credit_trajectory t
        ON h.customer_id = t.customer_id
       AND h.rn = t.rn + 1
),

customer_risk AS
(
    SELECT
        customer_id,

        MIN(CASE WHEN rn = 1
            THEN credit_score END) AS starting_score,

        MAX(CASE
            WHEN rn = (
                SELECT MAX(rn)
                FROM credit_history h2
                WHERE h2.customer_id = credit_trajectory.customer_id
            )
            THEN credit_score
        END) AS latest_score,

        MIN(credit_score) AS lowest_score,

        MAX(decline_streak) AS longest_decline_streak,

        SUM(
            CASE
                WHEN score_change < 0 THEN 1
                ELSE 0
            END
        ) AS declining_events,

        SUM(
            CASE
                WHEN score_change > 0 THEN 1
                ELSE 0
            END
        ) AS improving_events

    FROM credit_trajectory
    GROUP BY customer_id
)

SELECT
    customer_id,
    starting_score,
    latest_score,
    latest_score - starting_score AS overall_change,
    lowest_score,
    longest_decline_streak,
    declining_events,
    improving_events,

    CASE
        WHEN latest_score > starting_score
            THEN 'IMPROVING'

        WHEN latest_score < starting_score
            THEN 'DETERIORATING'

        ELSE 'STABLE'
    END AS trajectory

FROM customer_risk

ORDER BY customer_id;

-- =======
-- part 3a - Loan summary
-- ======

select 
 customer_id, 
count(*) as total_loans,
sum(amount) as total_loan_amount,
avg(amount) as average_loan_amount
from f_m_loans
 group by customer_id
 order by customer_id;
    
-- ======================
-- part 3b - default summary
-- =====================

select 
customer_id,
count(*) as default_count,
sum(overdue_amount) as total_overdue_amount,
max(default_date) as latest_default_date
from defaulters 
group by customer_id
order by customer_id;       
          
 select distinct status
 from f_m_loans;
 
 select distinct status
 from defaulters;
 
-- ==========================
-- part 3c- credit trajectory + loan exposure + default situation
-- ===============================

with recursive credit_history as
( 
select customer_id, event_date, event_type, reference_id, credit_score,
row_number() over(
 partition by customer_id
 order by event_date
 ) as rn
 from credit_score
 ),
 credit_trajectory as 
 ( 
 -- anchor: first event for each customer
 select customer_id, rn, event_date, event_type, reference_id, credit_score,
   credit_score as previous_score,
   0 as score_change,
   0 as decline_streak
   
   from credit_history
   where rn = 1
   
   union all
   
   -- recursive step: move to the next event
   
   select 
   h.customer_id, h.rn, h.event_date, h.event_type, h.reference_id, h.credit_score,
   t.credit_score as previous_score,
   h.credit_score - t.credit_score as score_change,
   
   case when h.credit_score < t.credit_score
           then t.decline_streak +1
           else 0
           end as decline_streak
           
   from credit_history h 
   join credit_trajectory t
   on h.customer_id = t.customer_id
   and h.rn = t.rn +1
   
   ),
   
   customer_risk as
   (
   select customer_id, 
   min(
      case 
      when rn = 1 then credit_score
      end
      )as starting_score,
      
   max(
    case
   when rn =( select max(h2.rn) from credit_history h2
                 where h2.customer_id = credit_trajectory.customer_id
                 )
    then credit_score
    end
    ) as latest_score,
    
    min(credit_score) as lowest_score,
    max(decline_streak) as longest_decline_streak,
    
    sum(
    case
      when score_change <0 then 1 else 0
      end
      ) as declining_events,
      
      sum(
      case 
      when score_change > 0 then 1 else 0
      end
      )as improving_events
      
      from credit_trajectory
      group by customer_id
      ),
      loan_summary as
      ( select customer_id, count(*) as total_loans,
         sum(amount) as total_historical_loan_amount,
         sum(
           case when status = 'active' then amount else 0
           end
           ) as active_loan_exposure,
          sum(
          case when status ='closed' then amount else 0
          end
          ) as closed_loan_amount
          
          from f_m_loans
          group by customer_id
          ),
           
           
     default_summary as
     (
     select customer_id, count(*) as default_count, sum(overdue_amount) as total_overdue_amount,
     max(default_date) as latest_default_date,
     
     group_concat(
     distinct status
     order by status
     separator ','
     ) as default_statuses
     
     from defaulters
     group by customer_id
     )
     
     select cr.customer_id, cr.starting_score, cr.latest_score,
      cr.latest_score - cr.starting_score as overall_score_change,
      cr.lowest_score, cr.longest_decline_streak, cr.declining_events, cr.improving_events,
      
      case
        when cr.latest_score > cr.starting_score
         then "improving"
         
         when cr.latest_score < cr.starting_score
         then "detoriating"
         
         else "stable"
         end as trajectory,
         
         coalesce(ls.total_loans,0) as total_loans,
         coalesce(ls.total_historical_loan_amount,0) as total_loan_historical_amount,
         coalesce(ls.active_loan_exposure,0) as active_loan_exposure,
         coalesce(ls.closed_loan_amount,0) as closed_loan_amount,
         coalesce(ds.default_count,0) as default_count,
         coalesce(ds.total_overdue_amount,0) as total_overdue_amount,
         ds.latest_default_date,
         coalesce(ds.default_statuses,"no default") as default_statuses
         from customer_risk cr
         left join loan_summary ls
         on cr.customer_id = ls.customer_id
         left join default_summary ds
         on cr.customer_id = ds.customer_id
         
         order by cr.customer_id;
                  
     
