package com.botscrew.model.outgoing.bmc.resource.status;

import lombok.Data;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
public class ResourceStatusResponse {

    private String name;
    private String ctm;
    private String available;
    private Integer max;
    private String workloadPolicy;
}
