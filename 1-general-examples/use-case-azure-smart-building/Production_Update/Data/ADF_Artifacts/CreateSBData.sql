CREATE TABLE SBDATA 
	(seq INT,
    detectiondate DATETIME,
	Temperature DECIMAL(16, 12), 
	Humidity DECIMAL(16, 12), 
	Light DECIMAL(16, 12),
	CO2 DECIMAL(16, 11),
	HumidityRatio DECIMAL(18, 17),
	Occupancy INT,
	ingestTime DATETIME
	);