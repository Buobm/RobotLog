#!/usr/bin/env bash
# /data/import.sh

echo "$(date +'%Y-%m-%d %H:%M:%S') | Starting import process..."

# 1) Wait for SQL Server to accept logins
echo "$(date +'%Y-%m-%d %H:%M:%S') | Waiting for SQL Server to start..."
until sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" \
             -d master -l 30 -b -C -N -Q "SELECT 1" > /dev/null 2>&1; do
  echo "$(date +'%Y-%m-%d %H:%M:%S') | SQL Server not ready yet..."
  sleep 5
done

echo "$(date +'%Y-%m-%d %H:%M:%S') | SQL Server is ready!"

# 2) Create DB & table if missing
echo "$(date +'%Y-%m-%d %H:%M:%S') | Creating database and table..."

# Wait a bit more for full database initialization
sleep 3

# First, create the database
sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" -b -C -N <<-EOSQL
  IF DB_ID('RobotData') IS NULL
  BEGIN
    CREATE DATABASE RobotData;
    PRINT 'Database RobotData created.';
  END
  ELSE
    PRINT 'Database RobotData already exists.';
EOSQL

if [ $? -ne 0 ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') | ERROR: Failed to create database."
    exit 1
fi

# Read CSV header to determine column structure
echo "$(date +'%Y-%m-%d %H:%M:%S') | Reading CSV header to determine table structure..."
CSV_HEADER=$(head -1 /data/robot_data.csv)
echo "$(date +'%Y-%m-%d %H:%M:%S') | CSV columns: $CSV_HEADER"

# Then, create the table dynamically based on CSV structure
sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" -d RobotData -b -C -N <<-EOSQL
  IF OBJECT_ID('dbo.Telemetry','U') IS NULL
  BEGIN
    CREATE TABLE dbo.Telemetry (
      Id INT IDENTITY PRIMARY KEY,
      Timestamp DATETIME2,
      GlobalX FLOAT,
      GlobalY FLOAT,
      GlobalYaw FLOAT,
      XVelocity FLOAT,
      YVelocity FLOAT,
      YawVelocity FLOAT,
      MotorTemp DECIMAL(5,2),
      BodyTemp DECIMAL(5,2),
      BatteryLevel INT,
      TimeToTarget INT,
      Mode NVARCHAR(50)
    );
    PRINT 'Table Telemetry created with dynamic structure.';
  END
  ELSE
    PRINT 'Table Telemetry already exists.';
EOSQL

if [ $? -eq 0 ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') | Table setup completed successfully."
else
    echo "$(date +'%Y-%m-%d %H:%M:%S') | ERROR: Failed to create table."
    exit 1
fi

# 3) Check if data already exists
echo "$(date +'%Y-%m-%d %H:%M:%S') | Checking if data already exists..."
ROW_COUNT=$(sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" -d RobotData -b -h-1 -C -N -Q "SELECT COUNT(*) FROM dbo.Telemetry" 2>/dev/null | head -1 | tr -d ' \r\n')

# Handle case where ROW_COUNT might be empty or contain non-numeric characters
if ! [[ "$ROW_COUNT" =~ ^[0-9]+$ ]]; then
    ROW_COUNT=0
fi

if [ "$ROW_COUNT" -gt 0 ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') | Data already exists ($ROW_COUNT rows). Skipping import."
else
    echo "$(date +'%Y-%m-%d %H:%M:%S') | No existing data found. Starting bulk import..."
    
    # 4) Import CSV using a temporary table approach
    echo "$(date +'%Y-%m-%d %H:%M:%S') | Starting bulk import using temporary table..."
    sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" -d RobotData -C -N -Q "
    -- Create temporary table with all columns as NVARCHAR for flexibility
    CREATE TABLE #TempTelemetry (
        Timestamp NVARCHAR(50),
        GlobalX NVARCHAR(50),
        GlobalY NVARCHAR(50),
        GlobalYaw NVARCHAR(50),
        XVelocity NVARCHAR(50),
        YVelocity NVARCHAR(50),
        YawVelocity NVARCHAR(50),
        MotorTemp NVARCHAR(50),
        BodyTemp NVARCHAR(50),
        BatteryLevel NVARCHAR(50),
        TimeToTarget NVARCHAR(50),
        Mode NVARCHAR(50)
    );
    
    -- Bulk insert into temp table
    BULK INSERT #TempTelemetry 
    FROM '/data/robot_data.csv'
    WITH (
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '\n',
        FIRSTROW = 2,
        KEEPNULLS
    );
    
    -- Insert into final table with proper data types and error handling
    INSERT INTO dbo.Telemetry (Timestamp, GlobalX, GlobalY, GlobalYaw, XVelocity, YVelocity, YawVelocity, MotorTemp, BodyTemp, BatteryLevel, TimeToTarget, Mode)
    SELECT 
        TRY_CONVERT(DATETIME2, Timestamp),
        TRY_CONVERT(FLOAT, GlobalX),
        TRY_CONVERT(FLOAT, GlobalY),
        TRY_CONVERT(FLOAT, GlobalYaw),
        TRY_CONVERT(FLOAT, XVelocity),
        TRY_CONVERT(FLOAT, YVelocity),
        TRY_CONVERT(FLOAT, YawVelocity),
        TRY_CONVERT(DECIMAL(5,2), MotorTemp),
        TRY_CONVERT(DECIMAL(5,2), BodyTemp),
        TRY_CONVERT(INT, BatteryLevel),
        TRY_CONVERT(INT, TimeToTarget),
        Mode
    FROM #TempTelemetry;
    
    -- Clean up
    DROP TABLE #TempTelemetry;
    
    SELECT @@ROWCOUNT as RowsInserted;
    "
    
    if [ $? -eq 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') | Import completed successfully."
        
        # Verify the import
        FINAL_COUNT=$(sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" -d RobotData -b -h-1 -C -N -Q "SELECT COUNT(*) FROM dbo.Telemetry" 2>/dev/null | tr -d ' \r\n')
        echo "$(date +'%Y-%m-%d %H:%M:%S') | Total rows imported: $FINAL_COUNT"
        
        # Show sample data
        echo "$(date +'%Y-%m-%d %H:%M:%S') | Sample of imported data:"
        sqlcmd -S localhost,1433 -U sa -P "$SA_PASSWORD" -d RobotData -C -N -Q "SELECT TOP 5 * FROM dbo.Telemetry ORDER BY Id"
    else
        echo "$(date +'%Y-%m-%d %H:%M:%S') | ERROR: Import failed."
        exit 1
    fi
fi

echo "$(date +'%Y-%m-%d %H:%M:%S') | Import process completed."
