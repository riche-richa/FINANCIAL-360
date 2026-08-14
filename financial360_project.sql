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
       
          
      
      
               
     