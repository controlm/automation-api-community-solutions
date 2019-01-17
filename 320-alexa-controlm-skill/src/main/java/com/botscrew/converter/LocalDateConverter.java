package com.botscrew.converter;

import javax.persistence.AttributeConverter;
import javax.persistence.Converter;
import java.sql.Date;
import java.time.LocalDate;

@Converter
public class LocalDateConverter implements AttributeConverter<LocalDate, Date> {

	@Override
	public Date convertToDatabaseColumn(final LocalDate entityValue) {
		if (entityValue != null) {
			return Date.valueOf(entityValue);
		}
		return null;
	}

	@Override
	public LocalDate convertToEntityAttribute(final Date databaseValue) {
		if (databaseValue != null) {
			return databaseValue.toLocalDate();
		}
		return null;
	}
}
