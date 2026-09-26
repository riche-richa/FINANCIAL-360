import mysql.connector
import pandas as pd

# -------------------------
# 1. connect to MySQL
# -------------------------

conn = mysql.connector.connect(
    host ="localhost",
    user ="root",
    password ="rich@9929",
    database ="finance_db"
    )   

print("MySQL connection successful")

# -----------------------------
# 2. part 3c risk query
# -----------------------------

query = """
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
"""

# -----------------------------
# 3. Run SQL and load into PANDAS
# -----------------------------

df = pd.read_sql(query,conn)

print("\nRisk dataset loaded successfully!")
print("Number of customers:", len(df))

print("\nFirst 10 customers:")
print(df.head(10))

# -----------------------------
# 4. basic risk summary
# -----------------------------

print("\nCustomer Risk Summary:")
print(df["trajectory"].value_counts())

# ------------------------------
# 5. Loan Exposure Summary
# ------------------------------

print("\nTotal Active Loan Exposure:")
print(df["active_loan_exposure"].sum())

# ---------------------------------
# 6. default summary
# ---------------------------------

print("\nCustomer with Defaults:")
print((df["default_count"]>0).sum())

# ---------------------------------
# 7. close connection
# --------------------------------

conn.close()
print("\nMySQL connection closed")
