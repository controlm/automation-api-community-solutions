import React from "react";
import ReactModal from "react-modal";
import "./SetDefaultModal.css";

class SetDefaultModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            closeModal: "img/closeModal.png"
        }
    }

    render() {
        return (
            <ReactModal
                className="set-default-environment-modal"
                overlayClassName="Overlay"
                isOpen={this.props.showModal}
            >
                <div className="modal-close-btn">
                    <img className="modal-close-img" src={this.state.closeModal}
                         onClick={this.props.handleCloseModal}/>
                </div>
                <div className="set-default-environment-modal-container">
                    <span className="del-env-modal-title">Currently <span className="modal-env-name">{this.props.oldEnvName}</span> is set as default. Are you sure you want to make <span className="modal-env-name">{this.props.newEnvName}</span> default?</span>
                    <div>
                        <button className="default-btn" onClick={this.props.setDefault}>Yes</button>
                        <button className="cancel-btn" onClick={this.props.handleCloseModal}>No</button>
                    </div>
                </div>
            </ReactModal>
        );
    }
}

export default SetDefaultModal;