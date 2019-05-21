import React, {Component} from 'react';
import "./DeleteEnvironmentModal.css";
import ReactModal from 'react-modal';

class DeleteEnvironmentModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            closeModal: "img/closeModal.png"
        }
    }

    render() {
        return (
            <ReactModal
                className="delete-environment-modal"
                overlayClassName="Overlay"
                isOpen={this.props.showModal}
            >
                <div className="modal-close-btn">
                    <img className="modal-close-img" src={this.state.closeModal}
                         onClick={this.props.handleCloseModal}/>
                </div>
                <div className="delete-environment-modal-container">
                    <span className="del-env-modal-title">Are you sure you want to delete <span
                        className="modal-env-name">{this.props.envName}</span>?</span>
                    <div>
                        <button className="default-btn" onClick={this.props.deleteHandler}>Delete</button>
                        <button className="cancel-btn" onClick={this.props.handleCloseModal}>Cancel</button>
                    </div>
                </div>
            </ReactModal>
        );
    }
}

export default DeleteEnvironmentModal;