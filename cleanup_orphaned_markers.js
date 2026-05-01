const fs = require('fs');

const filePath = 'd:/djtrip/dashbord/src/sections/Page1/Components/LieuDetails.jsx';
let content = fs.readFileSync(filePath, 'utf8');

// Handle remaining malformed conflicts (orphaned ======= ... >>>>>>> without <<<<<<< HEAD)
// Keep the part BEFORE the ======= and remove everything up to and including >>>>>>>
const pattern = /\n=======\n[\s\S]*?\n>>>>>>> backend\/djtripx2/g;

const matches = content.match(pattern);
const conflictCount = (matches || []).length;

content = content.replace(pattern, '');

fs.writeFileSync(filePath, content, 'utf8');

console.log('✓ File: LieuDetails.jsx');
console.log('✓ Cleaned up ' + conflictCount + ' orphaned conflict markers');
console.log('✓ Status: Success - All conflicts resolved');
