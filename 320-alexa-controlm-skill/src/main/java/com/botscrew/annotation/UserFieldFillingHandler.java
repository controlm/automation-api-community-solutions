package com.botscrew.annotation;

import com.botscrew.constant.State;
import com.botscrew.constant.UserVariables;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;


@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD})
public @interface UserFieldFillingHandler{

    State[] states() default {};

    UserVariables userVariable() default UserVariables.DEFAULT_VALUE;

}
