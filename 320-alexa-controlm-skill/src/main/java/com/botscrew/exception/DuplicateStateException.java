package com.botscrew.exception;

public class DuplicateStateException extends RuntimeException {
    public DuplicateStateException() {
    }

    public DuplicateStateException(String message) {
        super(message);
    }

    public DuplicateStateException(Throwable cause) {
        super(cause);
    }

    public DuplicateStateException(String message, Throwable cause) {
        super(message, cause);
    }

    public DuplicateStateException(String message, Throwable cause, boolean enableSuppression, boolean writableStackTrace) {
        super(message, cause, enableSuppression, writableStackTrace);
    }
}