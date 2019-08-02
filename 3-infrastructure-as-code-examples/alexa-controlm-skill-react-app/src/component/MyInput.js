import React from 'react';
import "./MyInput.css";

class MyInput extends React.Component {


    constructor(props) {
        super(props);
    }

    render() {
        return (
            <div className="my-input" style={{width: this.props.isLarge ? "540px" : "255px"}}>
                <div className="input-title-container">
                    <span className="input-name">{this.props.name}</span>
                    <span
                        className={"input-error-text " + (this.props.errorShown === undefined || this.props.errorShown === false ? "inactive" : "active")}>{this.props.errorText}</span>
                </div>
                <div className="input-group mb-3">
                    <input type={this.props.type === undefined ? "text" : this.props.type}
                           className={"form-control my-border " + (this.props.errorShown === undefined || this.props.errorShown === false ? "border-default" : "border-error")}
                           required={this.props.required}
                           value={this.props.value}
                           placeholder={this.props.placeholder === undefined ? "" : this.props.placeholder}
                           onChange={(e) => this.props.changeValue(e.target.value)}/>
                </div>
            </div>
        );
    }
}

export default MyInput;