package com.botscrew.exception;

import java.io.IOException;

public class HtmlMessageConverterException extends IOException {

    public HtmlMessageConverterException(){
        super();
    }

    public HtmlMessageConverterException(String msg){
        super(msg);
    }

}
