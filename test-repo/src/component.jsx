// React component with import patterns
import React from 'react';
import { wrapAnsi } from 'wrap-ansi';
import ansiRegex from 'ansi-regex';

const MyComponent = () => {
    const text = wrapAnsi('Hello', 10);
    const regex = ansiRegex();
    
    return (
        <div>
            <p>{text}</p>
        </div>
    );
};

export default MyComponent;
