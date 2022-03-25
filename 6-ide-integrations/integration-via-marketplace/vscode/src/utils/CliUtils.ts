/**
* ALL BMC SOFTWARE PRODUCTS LISTED WITHIN THE MATERIALS ARE TRADEMARKS OF BMC SOFTWARE, INC. ALL OTHER COMPANY PRODUCT NAMES
* ARE TRADEMARKS OF THEIR RESPECTIVE OWNERS.
*
* (c) Copyright 2022 BMC Software, Inc.
* This code is licensed under BSD-3 (see LICENSE.txt for details)
*/

import fs = require('fs');
import { CliArgs } from "../types/CliArgs";
import * as cp from "child_process";
import * as path from 'path';
import { OutputUtils } from "../utils/OutputUtils";
import { MessageUtils } from "./MessageUtils";
import * as vscode from "vscode";
import { promises } from "fs";
import { Constants } from './Constants';
import { CommonUtils } from './CommonUtils';

/**
 * Utility namespace for CLI operations.
 */
export namespace CliUtils {

  /**
   * Asynchronous function to assemble all the arguments for the CLI and call the CLI.
   * @param operation The Control-M AAPI operation to be executed (Constants.OP_BUILD, Constants.OP_RUN, Constants.OP_DEPLOY)
   * @param selectedFiles The files selected to run the operation on
   */
  export async function runCliCommandForOperation(operation: string, selectedFiles: vscode.Uri[]) {
    // OutputUtils.getOutputChannel().appendLine("Starting runCliCommandForOperation for operation " + operation);

    // assemble the arguments
    let cliLocation: string = Constants.EMPTY_STRING;
    let args: string[] = createCommandLineArgs({
      operation: operation,
      // file: getComponentFileNames(selectedFiles)
    });
    let ctmAapiCmd: string = 'ctm';

    // MessageUtils.showCtmInfoMessage("The CTM AAPI Job-As-Code: '" + ctmAapiCmd + " " + operation + " " + getFileNameToShow(selectedFiles) + "'");
    // OutputUtils.getOutputChannel().appendLine('CTM AAPI: ' + ctmAapiCmd + " " + operation + " '" + getFileNameToShow(selectedFiles) + "'");

    return executeCliCommand(ctmAapiCmd, args, selectedFiles);

  }

  /**
   * Constructor a string representation of files to operate on
   * @param selectedFiles the selected files to operate on
   */
  export function getFileNameToShow(selectedFiles: vscode.Uri[]): string {
    let fileNameToShow: string = selectedFiles.length === 1 ? path.basename(selectedFiles[0].fsPath) : selectedFiles.length + " files";
    return fileNameToShow;
  }

  /**
   * Constructor a string representation of files to operate on
   * @param selectedFiles the selected files to operate on
   */
  export function getFullFileNameToShow(selectedFiles: vscode.Uri[]): string {
    let fileNameToShow: string = selectedFiles.length === 1 ? selectedFiles[0].fsPath : selectedFiles.length + " files";
    return fileNameToShow;
  }

  /**
   * Constructor a string representation of files to operate on
   * @param selectedFiles the selected files to operate on
   */
  export function getParentFileNameToShow(selectedFiles: vscode.Uri[]): string {
    // let fileNameToShow: string = selectedFiles.length === 1 ? selectedFiles[0].fsPath : selectedFiles.length + " files";

    // let fileNameToShow: string = path.basename(selectedFiles[0].fsPath);
    let fileNameToShow: string = path.dirname(selectedFiles[0].fsPath);
    return fileNameToShow;
  }

  /**
   * Add close listener to the spawn child process
   * 
   * @param child the child process
   * @param operationToShow the operation message
   * @param fileNameToShow the file list
   */
  export function addCloseListener(child: cp.ChildProcessWithoutNullStreams | undefined, operationToShow: string, fileNameToShow: string) {
    if (child !== undefined) {
      child.on('close', code => {
        console.debug("The " + operationToShow + " process ended for " + fileNameToShow + ". CLI return code is " + code);
        if (code === 0) {
          // pass
          MessageUtils.showInfoMessage("The " + operationToShow + " process was successful for " + fileNameToShow);
        }
        else {
          // fail
          MessageUtils.showErrorMessage("The " + operationToShow + " process failed for " + fileNameToShow + ". Check the Control-M AAPI Output for more information.");
        }
      });
    }
  }

  /**
   * Creates a child process and calls the Control-M AAPI CLI
   * @param command The string CLI command to execute Control-M AAPI
   * @param args The arguments passed to the CLI (operation, files, etc)
   * @param selectedFiles The files selected to run Control-M AAPI action against
   */
  let processNumber: number = 1;
  async function executeCliCommand(command: string, args: string[], selectedFiles: vscode.Uri[]) {
    let procNumString: string = processNumber.toString().padStart(4, "0");

    // const child = require('child_process');
    // let file = vscode.workspace.getWorkspaceFolder(selectedFiles[0])?.uri.fsPath;
    let definitionsFile = getFileNameToShow(selectedFiles);
    let operation: string = args[1];
    let ctmFile: string = getFullFileNameToShow(selectedFiles);
    let ctmPath: string = getParentFileNameToShow(selectedFiles);
    let wsf = vscode.workspace.getWorkspaceFolder(selectedFiles[0])?.uri.path;
    let cmd = 'ctm ';

    OutputUtils.getOutputChannel().appendLine(procNumString + ' Operation: ' + operation);

    if (operation.toString() === "deploy transform") {
      // deploy transform <definitionsFile> <deployDescriptorFile>
      let deployDescriptorFile: string = path.basename(selectedFiles[1].fsPath);
      let definitionsFile: string = path.basename(selectedFiles[0].fsPath);
      
      // construct output file name
      const definitionsFileBase = path.basename(definitionsFile);
      const definitionsFileExtension = path.extname(definitionsFile);
      const definitionsFileBaseNoExt = path.basename(definitionsFileBase, definitionsFileExtension);
      let transformFile: string = definitionsFileBaseNoExt + '.transformed.' + Date.now() + '.json';

      OutputUtils.getOutputChannel().appendLine(procNumString + ' Transformed Output File: ' + transformFile);

      cmd = 'ctm ' + operation + ' "' + definitionsFile + '" "' + deployDescriptorFile + '" > "' + transformFile + '"';
    } else {
      cmd = 'ctm ' + operation + ' "' + definitionsFile + '"';
    }

    // log ctm and file info
    OutputUtils.getOutputChannel().appendLine(procNumString + ' CTM AAPI: ' + cmd);

    // execute ctm aapi
    const child = cp.spawn(cmd, {
      shell: true,
      cwd: ctmPath
    });

    // add listener for when data is written to stdout
    child.stdout.on('data', (stdout) => {
      OutputUtils.getOutputChannel().appendLine(procNumString + ' Details : ' + stdout.toString());
    });

    // add listener for when data is written to stderr
    child.stderr.on('data', (stderr) => {
      let json = JSON.parse(stderr);
      OutputUtils.getOutputChannel().appendLine(procNumString + ' Message : ' + json.errors[0].message);
      OutputUtils.getOutputChannel().appendLine(procNumString + ' Details : ' + stderr.toString());
      MessageUtils.showErrorMessage("The " + operation + " process failed: " + json.errors[0].message);

    });

    if (processNumber < 9999) {
      processNumber++;
    }
    else {
      processNumber = 1;
    }

    return child;
  }

  /**
    * Concatenates the given URIs into a string of relative paths separated by a ":"
    * @param selectedFiles The selected file URIs to get paths for
    */
  function getComponentFileNames(selectedFiles: vscode.Uri[]): string {
    let componentNameStr: string = Constants.EMPTY_STRING;
    selectedFiles.forEach(componentUri => {
      componentNameStr = componentNameStr + ":" + vscode.workspace.asRelativePath(componentUri);
    });
    componentNameStr = componentNameStr.substring(1);

    return componentNameStr;
  }


  /**
   * Accepts an object of type CliArgs. Processes each field in the args object and appends a string argument to a string[]. Returns the final string[].
   * The final string[] can be passed to the CLI.
   * @param args a CliArgs object that needs to be broken down into a string array. Fields will only be appended if they have values.
   */
  function createCommandLineArgs(args: CliArgs): string[] {
    let strArgs: Array<string> = [];
    if (args.operation) { strArgs = strArgs.concat([' ', args.operation]); }
    // if (args.file) { strArgs = strArgs.concat([' ', CommonUtils.escapeString(args.file)]); }

    return strArgs;
  }


}