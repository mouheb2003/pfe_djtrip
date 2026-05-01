const fs = require('fs');

const filePath = 'd:/djtrip/dashbord/src/sections/Page1/Components/LieuDetails.jsx';
let content = fs.readFileSync(filePath, 'utf8');

// Try multiple regex patterns to handle different line endings
const patterns = [
  /<<<<<<< HEAD\n([\s\S]*?)\n=======\n[\s\S]*?\n>>>>>>> backend\/djtripx2/g,
  /<<<<<<< HEAD\r\n([\s\S]*?)\r\n=======\r\n[\s\S]*?\r\n>>>>>>> backend\/djtripx2/g
];

let conflictCount = 0;

// Try each pattern
for (const pattern of patterns) {
  const matches = content.match(pattern);
  if (matches && matches.length > 0) {
    conflictCount = matches.length;
    content = content.replace(pattern, '$1');
    console.log(`✓ Pattern matched with ${conflictCount} conflicts`);
    break;
  }
}

if (conflictCount === 0) {
  // Fallback: try a more permissive pattern
  const fallbackPattern = /<<<<<<< HEAD([\s\S]*?)=======([\s\S]*?)>>>>>>> backend\/djtripx2/g;
  const fallbackMatches = content.match(fallbackPattern);
  if (fallbackMatches && fallbackMatches.length > 0) {
    conflictCount = fallbackMatches.length;
    content = content.replace(fallbackPattern, function(match, head, backend) {
      return head;
    });
    console.log(`✓ Fallback pattern matched with ${conflictCount} conflicts`);
  }
}

// Write back to file
fs.writeFileSync(filePath, content, 'utf8');

console.log('✓ File: LieuDetails.jsx');
console.log('✓ Conflicts resolved: ' + conflictCount);
console.log('✓ Status: Success - File updated with HEAD version kept for all conflicts');
