package com.botscrew.model.outgoing.bmc.runjob;

import lombok.Data;

@Data
public class RunResponse {

    private String runId;
    private String statusURI;
}
