import React, {Component} from 'react';
import "./Environment.css";
import 'font-awesome/css/font-awesome.min.css';


class Environment extends React.Component {


    constructor(props) {
        super(props);
        this.state = {
            index: this.props.index,
            ip: this.props.elem.ip,
            login: this.props.elem.login,
            pass: this.props.elem.pass
        }
    }

    render() {
        return (
            <div className="environment">
                <div className="bound" style={{visibility: this.state.index === 0 ? 'hidden' : 'visible'}}/>
                <div className="environment-fields">
                    <div className="input-group mb-3">
                        {/*<div className="input-group-prepend">*/}
                        {/*<span className="input-group-text" id="inputGroup-sizing-default">Environment ip</span>*/}
                        {/*</div>*/}
                        <input type="text" className="form-control my-border"
                            // aria-label="Default"
                            // aria-describedby="inputGroup-sizing-sm"
                               defaultValue={this.props.elem.ip}
                               onChange={(e) => this.props.changeIp(e.target.value)}/>
                    </div>
                    <div className="">
                        {/*<div className="input-group-prepend">*/}
                        {/*<span className="input-group-text">Username and password</span>*/}
                        {/*</div>*/}
                        <input type="text" className="form-control my-border"
                               defaultValue={this.props.elem.login}
                               onChange={(e) => this.props.changeLogin(e.target.value)}/>
                        <input type="text" className="form-control my-border"
                               defaultValue={this.props.elem.pass}
                               onChange={(e) => this.props.changePass(e.target.value)}/>
                    </div>
                </div>
                <button className="trash-btn" onClick={this.props.deleteEnv}
                        style={{visibility: this.state.index === 0 ? 'hidden' : 'visible'}}><i className="fa fa-trash"/>
                </button>
            </div>
        );
    }
}

export default Environment;