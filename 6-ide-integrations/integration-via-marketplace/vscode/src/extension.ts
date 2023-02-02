import fs = require('fs');
import * as vscode from 'vscode';
import * as CtmCliCommand from "./commands/CliCommand";
import { Constants } from './utils/Constants';
import { OutputUtils } from "./utils/OutputUtils";
import { SettingsUtils } from "./utils/SettingsUtils";
import { CommonUtils } from './utils/CommonUtils';
import { MessageUtils } from "./utils/MessageUtils";

// this method is called once when your extension is activated
export function activate(context: vscode.ExtensionContext) {
	let validFile: boolean = true;

	console.log('Congratulations, your extension "Control-M Job-As-Code" is now active!');

	// CTM build
	let ctmBuild = vscode.commands.registerCommand(Constants.CMD_CTM_BUILD, async (selectedFile: vscode.Uri) => {
		let selectedFileUris: vscode.Uri[] = await getSelectedFileUris();
		CtmCliCommand.runCommand(Constants.OP_BUILD, undefined);
	});
	context.subscriptions.push(ctmBuild);

	// CTM run
	let ctmRun = vscode.commands.registerCommand(Constants.CMD_CTM_RUN, async (selectedFile: vscode.Uri) => {
		let selectedFileUris: vscode.Uri[] = await getSelectedFileUris();
		CtmCliCommand.runCommand(Constants.OP_RUN, undefined);
	});
	context.subscriptions.push(ctmRun);

	// CTM deploy
	let ctmDeploy = vscode.commands.registerCommand(Constants.CMD_CTM_DEPLOY, async (selectedFile: vscode.Uri) => {
		let selectedFileUris: vscode.Uri[] = await getSelectedFileUris();
		CtmCliCommand.runCommand(Constants.OP_DEPLOY, undefined);
	});
	context.subscriptions.push(ctmDeploy);

	// CTM deploy
	let ctmDeployTransform = vscode.commands.registerCommand(Constants.CMD_CTM_DEPLOY_TRANFORM, async (selectedFile: vscode.Uri) => {
		let selectedFileUris: vscode.Uri[] = await getSelectedFileUris();
		// let ctmDeployDescriptorFile: vscode.Uri[] = await getDirectory();

		let deployDescriptorFile: string | undefined = await SettingsUtils.getCtmDeployDescriptorWithPrompt();
		if (CommonUtils.isBlank(deployDescriptorFile) || deployDescriptorFile === undefined || !fs.existsSync(deployDescriptorFile)) {
			validFile = false;
			console.debug("A valid Control-M Deploy Descriptor File was not found.");
			MessageUtils.showWarningMessage('A valid Control-M Deploy Descriptor File was not found.');
		}

		if (validFile) {
			
			let deployDescriptorFileUri = vscode.Uri.file(deployDescriptorFile!);
			// selectedFileUris.push(deployDescriptorFileUri);
			selectedFileUris.push(vscode.Uri.file(deployDescriptorFile!));
			CtmCliCommand.runCommand(Constants.OP_DEPLOY_TRANSFORM, selectedFileUris );
		}
		// convert string paths into file URIs


	});
	context.subscriptions.push(ctmDeployTransform);
}

/**
 * Gets the file URIs of the files selected in the File Explorer view
 */
async function getSelectedFileUris(): Promise<vscode.Uri[]> {
	// get what's currently on the clipboard
	let prevText: string = await vscode.env.clipboard.readText();
	// copy selected file paths to clipboard and read
	await vscode.commands.executeCommand('copyFilePath');
	let selectedFilesStr: string = await vscode.env.clipboard.readText();
	// put old contents back on clipboard
	await vscode.env.clipboard.writeText(prevText);

	// convert string paths into file URIs
	let selectedFilesArr: string[] = selectedFilesStr.split(/\r\n/);
	console.debug("selectedFiles length: " + selectedFilesArr.length);
	let selectedFileUris: vscode.Uri[] = [];
	selectedFilesArr.forEach(filePath => {
		selectedFileUris.push(vscode.Uri.file(filePath));
	});
	return selectedFileUris;
}


async function getDirectory(): Promise<vscode.Uri[]> {
	return new Promise(async (resolve, reject) => {
		const dir = await showDialog();
		console.log("#1: " + String(dir)); //Outputs before dialog is closed.
	});
}

function showDialog() {
	// let dir = "";
	let dir: vscode.Uri[] = [];
	const options: vscode.OpenDialogOptions = {
		canSelectMany: false,
		openLabel: 'Open Deploy Descriptor file',
		canSelectFiles: true,
		canSelectFolders: false,
		filters: {
			'JSON files': ['json']
		}
	};
	vscode.window.showOpenDialog(options).then(fileUri => {

		if (fileUri && fileUri[0]) {
			console.log('#2: ' + fileUri[0].fsPath); //Outputs when dialog is closed.
			dir.push(vscode.Uri.file(fileUri[0].fsPath));
		}
	});
	return Promise.resolve(dir);
}




// this method is called when your extension is deactivated
export function deactivate() { }
