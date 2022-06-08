/**
* ALL BMC SOFTWARE PRODUCTS LISTED WITHIN THE MATERIALS ARE TRADEMARKS OF BMC SOFTWARE, INC. ALL OTHER COMPANY PRODUCT NAMES
* ARE TRADEMARKS OF THEIR RESPECTIVE OWNERS.
*
* (c) Copyright 2022 BMC Software, Inc.
* This code is licensed under BSD-3 license (see LICENSE.txt for details)
*/

import * as vscode from "vscode";

/**
 * Utility namespace for functions related to VSCode output channels
 */
export namespace OutputUtils {

    /**
     * Returns the instance of the CTM output channel. If no output channel exists, one is created and it is shown.
     */
    let _channel: vscode.OutputChannel;
    export function getOutputChannel(): vscode.OutputChannel {
        if (!_channel) {
            _channel = vscode.window.createOutputChannel("Control-M AAPI");
            _channel.show(true);
        }
        return _channel;
    }
}