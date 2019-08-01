import React from 'react';
import "./AddEnvironmentModal.css";
import ReactModal from 'react-modal';
import isUrl from 'is-url';
import {BASEURL} from '../ExternalFunction';


class AddEnvironmentModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            endpointErrorShown: false,
            environmentAlreadyExist: false,
            closeModal: "img/closeModal.png",
            selectedEnvName: this.props.envOptions[0]
        }
    }

    addEnvField = (name, changeValue, isLarge, placeholder = "", errorShown = false, errorText = "") => {
        return (
            <div className={"add-env-modal-field" + (isLarge ? "-large" : "-small")}>
                <div className="input-title-container">
                    <span className="input-name">{name}</span>
                    <span
                        className={"input-error-text " + (errorShown === false ? "inactive" : "active")}>{errorText}</span>
                </div>
                <div className="input-group mb-3">
                    <input type="text"
                           className={"form-control my-border " + (errorShown === false ? "border-default" : "border-error")}
                           required={true}
                           placeholder={placeholder}
                           onChange={(e) => changeValue(e.target.value)}/>
                </div>
            </div>
        );
    };

    refreshState = () => {
        this.state.selectedEnvName = this.props.envOptions[0];
        this.state.endpointErrorShown = false;
        this.state.username = "";
        this.state.username = "";
        this.state.password = "";
        this.state.endpoint = "";
    };

    createEnvironment = (username, password, endpoint, controlM, environmentName) => {
        const self = this;
        fetch(BASEURL + 'api/environments/' + this.props.userId, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username: username,
                password: password,
                endpoint: endpoint,
                controlM: controlM,
                environmentName: environmentName
            })
        })
            .then(
                function (response) {
                    if (response.status === 400) {
                        // console.log(response.text());
                        response.json().then(function (data) {
                            self.setState({
                                environmentAlreadyExist: true,
                                error: data.message
                            });
                        });

                    }
                    if (response.status === 200) {
                        response.json().then(function (data) {
                            self.refreshState();
                            self.props.createHandler();
                        });
                    }
                }
            )
            .catch(function (err) {
                console.log('Fetch Error :-S', err);
            });
    };

    getEnvNameOptions = () => {
        return this.props.envOptions.map((option) => {
            return <option value={option.value}>{option.label}</option>
        })
    };

    envNameHandleChange = (event) => {
        this.setState({selectedEnvName: event.target.value});
    };

    formSubmitted = (event, username, password, endpoint, controlM, environmentName) => {
        event.preventDefault();
        if (!isUrl(this.state.endpoint)) {
            this.setState({endpointErrorShown: true});
            return;
        } else {
            this.setState({endpointErrorShown: false});
        }
        this.createEnvironment(username, password, endpoint, controlM, environmentName);
    };

    render() {
        return (
            <ReactModal
                className="add-environment-modal"
                overlayClassName="Overlay"
                isOpen={this.props.showModal}
            >
                <div className="modal-close-btn">
                    <img className="modal-close-img" src={this.state.closeModal} onClick={() => {
                        this.refreshState();
                        this.props.handleCloseModal();
                    }}/>
                </div>
                <form className="add-environment-modal-container" onSubmit={(event) => {
                    this.formSubmitted(event, this.state.username, this.state.password, this.state.endpoint, this.state.controlM, this.state.selectedEnvName)
                }}>
                    <div className="add-environment-name">
                        <span className="modal-title">Add new environment</span>
                    </div>
                    <div className="add-environment-select-container">
                        <div className="add-env-modal-field-small">
                            <span className="input-name">Environment name</span>
                            <select className="add-environment-select"
                                    required
                                    value={this.state.selectedEnvName}
                                    onChange={this.envNameHandleChange}>
                                {this.getEnvNameOptions()}
                            </select>
                        </div>
                        {this.addEnvField("Control-M", (v) => {
                            this.setState({controlM: v})
                        }, false)}
                    </div>

                    <div className="modal-two-inputs">
                        {this.addEnvField("Username", (v) => {
                            this.setState({username: v})
                        }, false)}
                        {this.addEnvField("Password", (v) => {
                            this.setState({password: v})
                        }, false)}
                    </div>
                    {this.addEnvField("Endpoint", (v) => {
                        this.setState({endpoint: v})
                    }, true, "https://example.com:8443/automation-api", this.state.endpointErrorShown, "Please, provide valid endpoint")}
                    <div className="environment-already-exist-div"
                         style={{display: this.state.environmentAlreadyExist ? "block" : "none"}}>{this.state.error}
                    </div>
                    <div className="create-new-environment-container">
                        <input type="submit" value="Create" className="default-btn create-new-environment"/>
                    </div>
                </form>
            </ReactModal>
        );
    }
}

export default AddEnvironmentModal;