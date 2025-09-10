// Test file with various import patterns
const chalk = require('chalk');
const debug = require('debug');
import { supportsColor } from 'supports-color';
import ansiStyles from 'ansi-styles';

// Test function
function testFunction() {
    console.log(chalk.green('Hello World'));
    debug('Debug message');
    console.log(supportsColor.hasBasic);
    console.log(ansiStyles.green);
}

module.exports = { testFunction };
