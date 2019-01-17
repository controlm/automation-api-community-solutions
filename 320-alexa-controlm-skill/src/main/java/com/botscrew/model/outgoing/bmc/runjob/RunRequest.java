package com.botscrew.model.outgoing.bmc.runjob;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RunRequest {

    private String folder;
    private String jobs;
    private String ctm;

}
