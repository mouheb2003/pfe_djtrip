import dotenv from 'dotenv';
import githubService from '../services/githubService.js';
import localDocService from '../services/localDocService.js';
import documentParser from '../services/documentParser.js';
import chunkingService from '../services/chunkingService.js';
import embeddingService from '../services/embeddingService.js';
import vectorStorage from '../services/vectorStorage.js';
import cacheService from '../services/cacheService.js';
import { config, validateConfig } from '../config/index.js';

dotenv.config();

async function reindexDocumentation() {
  console.log('🚀 Starting documentation indexing (Incremental Mode)...');
  
  try {
    validateConfig();
    
    // Step 1: Fetch documentation
    console.log('\n📥 Step 1: Fetching documentation...');
    
    let githubFiles = [];
    try {
      githubFiles = await githubService.fetchAllDocumentation();
    } catch (e) {
      console.warn('⚠️ GitHub fetch failed, continuing with local files only.');
    }

    const localFiles = await localDocService.fetchAllDocumentation();

    // Merge files
    const fileMap = new Map();
    githubFiles.forEach(f => fileMap.set(f.path, f));
    localFiles.forEach(f => fileMap.set(f.path, f));
    
    const allFiles = Array.from(fileMap.values());
    console.log(`📋 Total files discovered: ${allFiles.length}`);

    // Load current metadata/index
    const existingMetadata = await vectorStorage.loadMetadata();
    const indexedFiles = existingMetadata.indexedFiles || {}; // path -> { hash, lastUpdated }
    
    const filesToUpdate = [];
    const filesToRemove = [];
    const unchangedPaths = [];

    // Identify changes
    for (const file of allFiles) {
      const existing = indexedFiles[file.path];
      if (!existing || existing.hash !== file.hash) {
        filesToUpdate.push(file);
      } else {
        unchangedPaths.push(file.path);
      }
    }

    // Identify removals
    const discoveredPaths = allFiles.map(f => f.path);
    for (const path of Object.keys(indexedFiles)) {
      if (!discoveredPaths.includes(path)) {
        filesToRemove.push(path);
      }
    }

    console.log(`✨ Status:`);
    console.log(`   - New/Modified: ${filesToUpdate.length}`);
    console.log(`   - Unchanged: ${unchangedPaths.length}`);
    console.log(`   - To Remove: ${filesToRemove.length}`);

    if (filesToUpdate.length === 0 && filesToRemove.length === 0) {
      console.log('\n✅ Everything is up to date. No indexing needed.');
      return;
    }

    // Step 2: Remove deleted files
    if (filesToRemove.length > 0) {
      console.log('\n🗑️  Step 2: Removing deleted files...');
      for (const path of filesToRemove) {
        await vectorStorage.deleteByPath(path);
        delete indexedFiles[path];
      }
    }

    // Step 3 & 4 & 5: Process updates incrementally
    if (filesToUpdate.length > 0) {
      console.log(`\n📝 Processing ${filesToUpdate.length} new/modified files...`);
      
      for (let i = 0; i < filesToUpdate.length; i++) {
        const file = filesToUpdate[i];
        console.log(`\n📄 [${i + 1}/${filesToUpdate.length}] Indexing: ${file.path}`);
        
        try {
          const parsedDoc = documentParser.parse(file);
          const chunks = chunkingService.chunkDocument(parsedDoc, 'headings');
          
          if (chunks.length > 0) {
            console.log(`   - Generating embeddings for ${chunks.length} chunks...`);
            const chunksWithEmbeddings = await embeddingService.generateChunkEmbeddings(chunks);
            
            console.log(`   - Storing in vector database...`);
            await vectorStorage.storeChunks(chunksWithEmbeddings);
          }

          // Update local tracking
          indexedFiles[file.path] = {
            hash: file.hash,
            lastUpdated: new Date().toISOString()
          };

          // SAVE PROGRESS IMMEDIATELY (So we can resume if interrupted)
          await vectorStorage.updateMetadata('indexedFiles', indexedFiles);
          await vectorStorage.updateMetadata('lastIndexed', new Date().toISOString());
          
        } catch (error) {
          console.error(`❌ Failed to index ${file.path}:`, error.message);
          // Continue with next file
        }
      }
    }
    
    // Step 7: Clear cache
    console.log('\n🧹 Step 7: Clearing cache...');
    cacheService.clear();
    await cacheService.saveCache();
    
    const storageStats = await vectorStorage.getStorageStats();
    console.log(`\n📈 Final Statistics:`);
    console.log(`   - Total chunks in DB: ${storageStats.totalChunks}`);
    console.log(`   - Total files indexed: ${Object.keys(indexedFiles).length}`);
    
    console.log('\n✅ Incremental indexing completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Indexing failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the reindexing
reindexDocumentation()
  .then(() => {
    console.log('\n🎉 All done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });
