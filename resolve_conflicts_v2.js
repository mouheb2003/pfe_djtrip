const fs = require('fs');
const path = require('path');

const filePath = 'd:/djtrip/dashbord/src/sections/Page1/Components/LieuDetails.jsx';
let content = fs.readFileSync(filePath, 'utf8');
const originalContent = content;

let conflictCount = 0;

// Strategy: Find all conflicts and resolve them one by one

// Pattern 1: Standard conflicts with HEAD markers
const pattern1 = /<<<<<<< HEAD\n([\s\S]*?)\n=======\n[\s\S]*?\n>>>>>>> backend\/djtripx2/g;
const matches1 = content.match(pattern1);
if (matches1 && matches1.length > 0) {
  console.log(`Found ${matches1.length} standard conflicts`);
  conflictCount += matches1.length;
  content = content.replace(pattern1, '$1');
}

// Pattern 2: Conflicts without leading <<<<<<< HEAD (malformed)
// These start directly at ======= 
const pattern2 = /=======\n([\s\S]*?)\n>>>>>>> backend\/djtripx2/g;
const remaining2 = content.match(pattern2);
if (remaining2 && remaining2.length > 0) {
  console.log(`Found ${remaining2.length} conflicts without HEAD marker (malformed)`);
  conflictCount += remaining2.length;
  // For these, keep empty/remove the alternative since we don't have HEAD part visible
  content = content.replace(pattern2, '');
}

// Pattern 3: Remaining HEAD markers with arbitrary following content
const pattern3 = /<<<<<<< HEAD\n([\s\S]*?)(?=(\n=======\n|$))/g;
const matches3 = (content.match(/<<<<<<< HEAD/g) || []);
if (matches3.length > 0) {
  console.log(`Found ${matches3.length} remaining HEAD markers to clean up`);
  // More careful resolution
  let inConflict = false;
  const lines = content.split('\n');
  const resolved = [];
  let i = 0;
  
  while (i < lines.length) {
    const line = lines[i];
    
    if (line.includes('<<<<<<< HEAD')) {
      inConflict = true;
      let headContent = [];
      i++;
      
      // Collect HEAD section
      while (i < lines.length && !lines[i].includes('=======')) {
        headContent.push(lines[i]);
        i++;
      }
      
      // Skip to after ======= and >>>>>>> markers
      while (i < lines.length && !lines[i].includes('>>>>>>> backend/djtripx2')) {
        i++;
      }
      i++; // skip the >>>>>>> line
      
      // Add only the HEAD content
      resolved.push(...headContent);
      conflictCount++;
      inConflict = false;
    } else {
      resolved.push(line);
      i++;
    }
  }
  
  content = resolved.join('\n');
}

// Write back to file
fs.writeFileSync(filePath, content, 'utf8');

console.log('✓ File: LieuDetails.jsx');
console.log('✓ Total conflicts resolved: ' + conflictCount);
console.log('✓ Status: Success - File updated with HEAD version kept for all conflicts');
