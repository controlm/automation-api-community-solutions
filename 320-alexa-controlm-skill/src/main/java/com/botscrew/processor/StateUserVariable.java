package com.botscrew.processor;

import com.botscrew.constant.State;
import com.botscrew.constant.UserVariables;
import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class StateUserVariable {

    private State state;

    private UserVariables userVariables;

    @Override
    public int hashCode() {
        int result = 1;
        result = 31 * result + (this.getUserVariables()== null ? 0 : this.getUserVariables().hashCode());
        result = 31 * result + (this.getState() == null ? 0 : this.getState().hashCode());
        return result;
    }

    @Override
    public boolean equals(Object obj){
        return obj instanceof StateUserVariable && this.isEquivalent((StateUserVariable) obj);
    }

    private boolean isEquivalent(StateUserVariable obj) {
        return this.getState().equals(obj.getState()) && this.getUserVariables().equals(obj.getUserVariables());
    }
}
