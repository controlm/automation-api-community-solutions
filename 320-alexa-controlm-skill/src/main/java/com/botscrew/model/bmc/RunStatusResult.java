package com.botscrew.model.bmc;

import com.botscrew.constant.Result;
import com.botscrew.model.outgoing.bmc.resource.status.ResourceStatusResponse;
import com.botscrew.model.outgoing.bmc.runstatus.RunStatusResponse;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RunStatusResult {

    private RunStatusResponse runStatusResponse;
    private Result result;

}
