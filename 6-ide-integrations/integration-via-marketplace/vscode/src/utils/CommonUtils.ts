/**
* ALL BMC SOFTWARE PRODUCTS LISTED WITHIN THE MATERIALS ARE TRADEMARKS OF BMC SOFTWARE, INC. ALL OTHER COMPANY PRODUCT NAMES
* ARE TRADEMARKS OF THEIR RESPECTIVE OWNERS.
*
* (c) Copyright 2022 BMC Software, Inc.
* This code is licensed under BSD-3 license (see LICENSE.txt for details)
*/

import { SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS } from "constants";

/**
 * Utility namespace for functions related to VSCode output channels
 */
export namespace CommonUtils {

    const _ = require('lodash');

    /**
     * Test if the input value is blank
     * 
     * @param value the value to be tested
     */
    export function isBlank(value: any): boolean {
        let newValue = value;

        if (_.isString(value)) {
            newValue = _.trim(value);
        }

        return _.isEmpty(newValue) && !_.isNumber(newValue) || _.isNaN(newValue);
    }

    /**
     * Test if the input value is not blank
     * 
     * @param value the value to be tested
     */
    export function isNotBlank(value: any): boolean {
        return !isBlank(value);
    }

    /**
     * Detect if running inside Mocha
     */
    export function isInMocha() {
        var context = require('global-var');
        return ['suite', 'test'].every(function (functionName) {
            return context[functionName] instanceof Function;
        });
    }

    /**
     * Adds escaped quotation marks around the given string
     * @param value a string to add quotes around
     */
    export function escapeString(value: any): string {
        let escapedString: string = '\"' + (value || '') + '\"';
        return escapedString;
    }

}