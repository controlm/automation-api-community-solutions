package com.botscrew.model.outgoing.bmc.resource.status;

import lombok.Data;

import java.util.ArrayList;
import java.util.List;

@Data
public class ResourceStatusResponseList {

    private List<ResourceStatusResponse> resourceStatuses;

    public ResourceStatusResponseList() {
        resourceStatuses = new ArrayList<>();
    }

}
