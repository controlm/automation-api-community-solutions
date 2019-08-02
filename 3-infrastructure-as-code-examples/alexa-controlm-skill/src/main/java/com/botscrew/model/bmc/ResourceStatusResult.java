package com.botscrew.model.bmc;

import com.botscrew.constant.Result;
import com.botscrew.model.outgoing.bmc.resource.status.ResourceStatusResponse;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResourceStatusResult {

    private ResourceStatusResponse resourceStatusResponse;
    private Result result;

}
