import localDocService from './src/services/localDocService.js';
import vectorStorage from './src/services/vectorStorage.js';

async function checkStatus() {
  console.log('🔍 Analyzing indexing status...');
  
  const discoveredFiles = await localDocService.fetchAllDocumentation();
  const metadata = await vectorStorage.loadMetadata();
  const indexedFiles = metadata.indexedFiles || {};
  
  const totalDiscovered = discoveredFiles.length;
  const totalIndexed = Object.keys(indexedFiles).length;
  
  const missingFiles = discoveredFiles.filter(f => !indexedFiles[f.path]);
  const modifiedFiles = discoveredFiles.filter(f => indexedFiles[f.path] && indexedFiles[f.path].hash !== f.hash);
  
  console.log('\n📊 Indexing Summary:');
  console.log(`- Total files discovered: ${totalDiscovered}`);
  console.log(`- Total files indexed:    ${totalIndexed}`);
  console.log(`- Progress:               ${((totalIndexed / totalDiscovered) * 100).toFixed(2)}%`);
  
  console.log('\n📁 Documentation folder status:');
  const docFiles = discoveredFiles.filter(f => f.path.startsWith('documentation'));
  const indexedDocFiles = docFiles.filter(f => indexedFiles[f.path]);
  console.log(`- Found:   ${docFiles.length} files`);
  console.log(`- Indexed: ${indexedDocFiles.length} files`);
  
  if (missingFiles.length > 0) {
    console.log(`\n⚠️ Missing ${missingFiles.length} files from index.`);
  }
  
  if (modifiedFiles.length > 0) {
    console.log(`\n🔄 Found ${modifiedFiles.length} modified files.`);
  }

  if (metadata.lastIndexed) {
    console.log(`\n📅 Last indexing: ${metadata.lastIndexed}`);
  }
}

checkStatus();
