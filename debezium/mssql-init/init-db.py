import pymssql
import time

# ==========================================
# 1. Connection Configuration
# ==========================================
SERVER = 'localhost'
PORT = '1433'
USERNAME = 'sa'
PASSWORD = 'YourStrong!Passw0rd'  # Must match docker-compose.yml

def setup_database():
    print("Connecting to SQL Server (Master DB)...")
    
    try:
        # Wait 5 seconds in case this script runs while Docker just started
        time.sleep(5)
        
        # Connect to master database first to have permissions to create a new database (use autocommit=True)
        conn = pymssql.connect(server=SERVER, port=PORT, user=USERNAME, password=PASSWORD, database='master', autocommit=True)
        cursor = conn.cursor()
        
        print("1. Creating database 'sourcedb'...")
        try:
            cursor.execute("CREATE DATABASE sourcedb")
            print("   -> Database created successfully")
        except pymssql.DatabaseError as e:
            # Prevent error if script is run again and database already exists
            if 'already exists' in str(e):
                print("   -> Database already exists, skipping creation")
            else:
                raise e
        conn.close()

        # ==========================================
        # 2. Connect to sourcedb to enable CDC system
        # ==========================================
        print("\nConnecting to database 'sourcedb'...")
        conn = pymssql.connect(server=SERVER, port=PORT, user=USERNAME, password=PASSWORD, database='sourcedb', autocommit=True)
        cursor = conn.cursor()

        print("2. Enabling CDC at database level...")
        try:
            cursor.execute("EXEC sys.sp_cdc_enable_db")
            print("   -> CDC enabled at DB level successfully")
        except Exception as e:
            print(f"   -> Info: {e}") # May have been enabled from a previous run

        print("3. Creating 'customers' table...")
        try:
            cursor.execute("""
            CREATE TABLE customers (
                id INT IDENTITY(1,1) PRIMARY KEY,
                name VARCHAR(50),
                email VARCHAR(50)
            )
            """)
            print("   -> 'customers' table created successfully")
        except Exception as e:
            print(f"   -> Info: {e}") # May have been created already

        print("4. Enabling CDC for 'customers' table...")
        try:
            cursor.execute("""
            EXEC sys.sp_cdc_enable_table
                @source_schema = N'dbo',
                @source_name   = N'customers',
                @role_name     = NULL;
            """)
            print("   -> CDC enabled on 'customers' table successfully")
        except Exception as e:
            print(f"   -> Info: {e}")

        conn.close()
        print("\nMSSQL and CDC setup complete. Ready for Debezium to read data!")

    except pymssql.Error as e:
        print(f"Connection failed: {e}")
        print("Please verify that SQL Server Docker is running and that the User/Password is correct")

if __name__ == "__main__":
    setup_database()
