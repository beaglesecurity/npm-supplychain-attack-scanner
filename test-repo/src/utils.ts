// TypeScript file with import patterns
import * as chalk from 'chalk';
import { stripAnsi } from 'strip-ansi';
import debug from 'debug';

export function formatText(text: string): string {
    return chalk.blue(stripAnsi(text));
}

export function logDebug(message: string): void {
    debug('app')(message);
}
