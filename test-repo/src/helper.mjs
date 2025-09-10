// ES module with dynamic import
import('color-convert').then(convert => {
    console.log(convert.rgb.hex(255, 0, 0));
});

// Also test require pattern
const colorName = require('color-name');
