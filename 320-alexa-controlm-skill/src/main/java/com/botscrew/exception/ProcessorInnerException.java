package com.botscrew.exception;

public class ProcessorInnerException extends RuntimeException {
    public ProcessorInnerException() {
    }

    public ProcessorInnerException(String message, Throwable cause) {
        super(message, cause);
    }

    public ProcessorInnerException(String message) {
        super(message);
    }

    public ProcessorInnerException(Throwable cause) {
        super(cause);
    }
}
