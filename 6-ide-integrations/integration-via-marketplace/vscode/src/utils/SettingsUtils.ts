/**
* ALL BMC SOFTWARE PRODUCTS LISTED WITHIN THE MATERIALS ARE TRADEMARKS OF BMC SOFTWARE, INC. ALL OTHER COMPANY PRODUCT NAMES
* ARE TRADEMARKS OF THEIR RESPECTIVE OWNERS.
*
* (c) Copyright 2022 BMC Software, Inc.
* This code is licensed under MIT license (see LICENSE.txt for details)
*/

import * as vscode from "vscode";
import fs = require('fs');
import { Constants } from '../utils/Constants';
import { CommonUtils } from '../utils/CommonUtils';

export namespace SettingsUtils {

    export async function getCtmDeployDescriptorWithPrompt(): Promise<string | undefined> {
        let deployDescriptorFile = Constants.EMPTY_STRING;

        if (CommonUtils.isBlank(deployDescriptorFile)) {
            await vscode.window.showQuickPick(
                [
                    { 
                        label: 'Find...', 
                        description: 'Browse your file system to locate the Control-M Deploy Descriptor' 
                    },
                ],
                {
                    placeHolder: 'Select Control-M Deploy Descriptor'
                }).then(async selection => {
                    if (!selection) {
                        return;
                    }

                    switch (selection.label) {
                        case 'Find...':
                            const options: vscode.OpenDialogOptions = {
                                canSelectFiles: true,
                                canSelectFolders: false
                            };
                            await vscode.window.showOpenDialog(options).then(async selection => {
                                if (selection) {
                                    deployDescriptorFile = selection[0].fsPath;
                                }
                            });

                            break;

                        default:
                            break;
                    }
                });
        }

        return deployDescriptorFile;
    }

}