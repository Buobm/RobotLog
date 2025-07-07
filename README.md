# Robot Telemetry Database

A minimal Docker setup that runs an MSSQL database and automatically imports example robot telemetry data from a CSV file.

## What it does

- Starts an MSSQL Server 2022 database in Docker
- Creates a `RobotData` database with a `Telemetry` table
- Automatically imports robot sensor data from `robot_data.csv`

## Quick Start

```bash
docker-compose up
```

The database will be available on `localhost:1433` with:
- Username: `sa`
- Password: `Holzweg247!`
- Database: `RobotData`
- Table: `Telemetry`

## Example Table Structure

The `Telemetry` table contains robot sensor data:

| Column | Type | Description |
|--------|------|-------------|
| Timestamp | DATETIME2 | When the data was recorded |
| GlobalX/Y | FLOAT | Robot position coordinates |
| GlobalYaw | FLOAT | Robot orientation |
| XVelocity/YVelocity/YawVelocity | FLOAT | Movement speeds |
| MotorTemp/BodyTemp | DECIMAL | Temperature sensors |
| BatteryLevel | INT | Battery percentage |
| TimeToTarget | INT | Seconds to destination |
| Mode | NVARCHAR | Current robot mode (e.g., "Idle", "Delivering Tool") |

## Sample Query

```sql
SELECT TOP 10 Timestamp, GlobalX, GlobalY, Mode, BatteryLevel 
FROM RobotData.dbo.Telemetry 
ORDER BY Timestamp DESC;
```
