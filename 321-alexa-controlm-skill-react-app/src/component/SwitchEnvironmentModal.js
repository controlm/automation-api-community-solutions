import React, {Component} from 'react';
import "./SwitchEnvironmentModal.css";
import ReactModal from 'react-modal';

class SwitchEnvironmentModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            closeModal: "img/closeModal.png"
        }
    }

    render() {
        return (
            <ReactModal
                className="switch-environment-modal"
                overlayClassName="Overlay"
                isOpen={this.props.showModal}
            >
                <div className="modal-close-btn">
                    <img className="modal-close-img" src={this.state.closeModal}
                         onClick={this.props.handleCloseModal}/>
                </div>
                <div className="switch-environment-modal-container">
                    <span className="switch-env-modal-title">Are you sure you want to switch the environment? All unsaved changes would be deleted.</span>
                    <div>
                        <button className="default-btn" onClick={this.props.switchEnvHandler}>Yes</button>
                        <button className="cancel-btn" onClick={this.props.handleCloseModal}>No</button>
                    </div>
                </div>
            </ReactModal>
        );
    }
}

export default SwitchEnvironmentModal;