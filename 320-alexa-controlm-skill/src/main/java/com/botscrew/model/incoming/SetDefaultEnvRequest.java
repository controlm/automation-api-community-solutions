package com.botscrew.model.incoming;

import lombok.Data;

@Data
public class SetDefaultEnvRequest {

    private Long userId;
    private Long environmentId;

}
