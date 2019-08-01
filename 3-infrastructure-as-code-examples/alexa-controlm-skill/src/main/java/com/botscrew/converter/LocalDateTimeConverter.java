package com.botscrew.converter;

import javax.persistence.AttributeConverter;
import javax.persistence.Converter;
import java.time.LocalDateTime;

@Converter
public class LocalDateTimeConverter implements AttributeConverter<LocalDateTime, java.sql.Timestamp> {

	@Override
	public java.sql.Timestamp convertToDatabaseColumn(final LocalDateTime entityValue) {
		if (entityValue != null) {
			return java.sql.Timestamp.valueOf(entityValue);
		}
		return null;
	}

	@Override
	public LocalDateTime convertToEntityAttribute(final java.sql.Timestamp databaseValue) {
		if (databaseValue != null) {
			return databaseValue.toLocalDateTime();
		}
		return null;
	}
}
