
import mysql.connector

search_pan = input("Enter PAN (press enter if unavailable): ")
search_aadhaar = input("Enter AADHAAR (press enter if unavailable): ")

connection = mysql.connector.connect(
    host="localhost",
    user="XXXXX",
    password="XXXXXXXXX",
    database="finance_db"
)

cursor = connection.cursor()

cursor.callproc(
    "find_customer",
    (search_pan or None, search_aadhaar or None)
)

for result in cursor.stored_results():
    for row in result.fetchall():
        print(row)

cursor.close()
connection.close()


