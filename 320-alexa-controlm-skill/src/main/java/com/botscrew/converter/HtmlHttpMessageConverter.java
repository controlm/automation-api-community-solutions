package com.botscrew.converter;

import com.botscrew.exception.HtmlMessageConverterException;
import org.springframework.http.HttpInputMessage;
import org.springframework.http.HttpOutputMessage;
import org.springframework.http.MediaType;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.http.converter.HttpMessageNotWritableException;

import java.io.IOException;
import java.util.Collections;
import java.util.List;

public class HtmlHttpMessageConverter implements HttpMessageConverter {

    @Override
    public boolean canRead(Class aClass, MediaType mediaType) {
        return MediaType.TEXT_HTML.equals(mediaType);
    }

    @Override
    public boolean canWrite(Class aClass, MediaType mediaType) {
        return MediaType.TEXT_HTML.equals(mediaType);
    }

    @Override
    public List<MediaType> getSupportedMediaTypes() {
        return Collections.singletonList(MediaType.TEXT_HTML);
    }

    @Override
    public Object read(Class aClass, HttpInputMessage httpInputMessage) throws IOException, HttpMessageNotReadableException {
        throw new HtmlMessageConverterException(((ClientHttpResponse)httpInputMessage).getStatusText());
    }

    @Override
    public void write(Object o, MediaType mediaType, HttpOutputMessage httpOutputMessage) throws IOException, HttpMessageNotWritableException {
        throw new HtmlMessageConverterException();
    }
}
