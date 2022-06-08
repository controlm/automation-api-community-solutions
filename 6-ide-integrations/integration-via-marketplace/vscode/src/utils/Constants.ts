/**
* ALL BMC SOFTWARE PRODUCTS LISTED WITHIN THE MATERIALS ARE TRADEMARKS OF BMC SOFTWARE, INC. ALL OTHER COMPANY PRODUCT NAMES
* ARE TRADEMARKS OF THEIR RESPECTIVE OWNERS.
*
* (c) Copyright 2022 BMC Software, Inc.
* This code is licensed under MIT license (see LICENSE.txt for details)
*/

export abstract class Constants {

    static readonly CMD_CTM_BUILD : string = 'CTM.build';
    static readonly CMD_CTM_RUN : string = 'CTM.run';
    static readonly CMD_CTM_DEPLOY : string = 'CTM.deploy';
    static readonly CMD_CTM_DEPLOY_TRANFORM : string = 'CTM.deploy.transform';

    static readonly OP_BUILD : string = 'build';
    static readonly OP_RUN : string = 'run';
    static readonly OP_DEPLOY : string = 'deploy';
    static readonly OP_DEPLOY_TRANSFORM : string = 'deploy transform';

    static readonly EMPTY_STRING : string = '';
}