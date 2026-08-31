import mysql.connector

# Connect to MySQL

connection = mysql.connector.connect(
    host='XXXXX',
    user='root',
    port=XXXX,
    password='XXXXX',
    database='finance_db'
)

print("Connected successfully!")

cursor = connection.cursor()

query = """
WITH transaction_check AS
(
    SELECT 
        a.customer_id,
        t.txn_id,
        t.date,
        t.amount,
        COUNT(*) OVER (
            PARTITION BY a.customer_id, t.amount
        ) AS same_amount_count
    FROM transactions t
    JOIN accounts a
        ON a.account_id = t.account_id
)

SELECT 
    customer_id,
    txn_id,
    date,
    amount,
    same_amount_count
FROM transaction_check
WHERE same_amount_count > 1
ORDER BY customer_id, amount, date;
"""

cursor.execute(query)
results = cursor.fetchall()

for row in results:
    print(row)

cursor.close()
connection.close()
