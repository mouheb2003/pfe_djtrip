import localDocService from './src/services/localDocService.js';

async function test() {
  const files = await localDocService.fetchAllDocumentation();
  console.log('Files found:', files.length);
  const docFiles = files.filter(f => f.path.startsWith('documentation'));
  console.log('Documentation files found:', docFiles.length);
  docFiles.forEach(f => console.log(' - ' + f.path));
}

test();
