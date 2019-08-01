package com.botscrew.model.incoming;

import com.botscrew.constant.EnvironmentName;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import javax.persistence.EnumType;
import javax.persistence.Enumerated;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class EnvironmentModel {

    private Long id;

    private String controlM;

    private String endpoint;

    private String username;

    private String password;

    private String jobName;

    @Enumerated(EnumType.STRING)
    private EnvironmentName environmentName;

    private String folderName;

    private String fileName;

    private String eventName;

    private String value;

    private String resource;

//    private Long userId;

    private Boolean currentSelected;

    private Boolean usersDefault;

}
