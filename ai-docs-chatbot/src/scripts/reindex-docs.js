import dotenv from 'dotenv';
import githubService from '../services/githubService.js';
import documentParser from '../services/documentParser.js';
import chunkingService from '../services/chunkingService.js';
import embeddingService from '../services/embeddingService.js';
import vectorStorage from '../services/vectorStorage.js';
import cacheService from '../services/cacheService.js';
import { config, validateConfig } from '../config/index.js';

dotenv.config();

async function reindexDocumentation() {
  console.log('🚀 Starting documentation reindexing...');
  console.log(`📚 Repository: ${config.githubOwner}/${config.githubRepo}`);
  console.log(`🌿 Branch: ${config.githubBranch}`);
  
  try {
    validateConfig();
    
    // Step 1: Fetch documentation from GitHub
    console.log('\n📥 Step 1: Fetching documentation from GitHub...');
    const files = await githubService.fetchAllDocumentation();
    console.log(`✅ Fetched ${files.length} files`);
    
    // Step 2: Parse documentation
    console.log('\n📝 Step 2: Parsing documentation...');
    const parsedDocuments = documentParser.parseMultiple(files);
    console.log(`✅ Parsed ${parsedDocuments.length} documents`);
    
    // Display document statistics
    const docStats = {
      totalFiles: parsedDocuments.length,
      totalSize: parsedDocuments.reduce((sum, doc) => sum + doc.size, 0),
      avgSize: Math.round(
        parsedDocuments.reduce((sum, doc) => sum + doc.size, 0) / parsedDocuments.length
      ),
    };
    console.log(`   - Total size: ${docStats.totalSize} bytes`);
    console.log(`   - Average size: ${docStats.avgSize} bytes`);
    
    // Step 3: Chunk documents
    console.log('\n✂️  Step 3: Chunking documents...');
    const chunks = chunkingService.chunkMultipleDocuments(parsedDocuments, 'headings');
    console.log(`✅ Created ${chunks.length} chunks`);
    
    const chunkStats = chunkingService.getChunkStatistics(chunks);
    console.log(`   - Average chunk length: ${chunkStats.avgLength} characters`);
    console.log(`   - Min chunk length: ${chunkStats.minLength} characters`);
    console.log(`   - Max chunk length: ${chunkStats.maxLength} characters`);
    
    // Step 4: Generate embeddings
    console.log('\n🧠 Step 4: Generating embeddings...');
    const chunksWithEmbeddings = await embeddingService.generateChunkEmbeddings(chunks);
    console.log(`✅ Generated ${chunksWithEmbeddings.length} embeddings`);
    console.log(`   - Embedding dimension: ${chunksWithEmbeddings[0].embeddingDimension}`);
    
    // Step 5: Clear existing storage
    console.log('\n🗑️  Step 5: Clearing existing storage...');
    await vectorStorage.clear();
    console.log('✅ Storage cleared');
    
    // Step 6: Store vectors
    console.log('\n💾 Step 6: Storing vectors...');
    await vectorStorage.storeChunks(chunksWithEmbeddings);
    console.log('✅ Vectors stored successfully');
    
    // Step 7: Update metadata
    console.log('\n📊 Step 7: Updating metadata...');
    await vectorStorage.updateMetadata('lastIndexed', new Date().toISOString());
    await vectorStorage.updateMetadata('totalChunks', chunksWithEmbeddings.length);
    await vectorStorage.updateMetadata('repository', {
      owner: config.githubOwner,
      repo: config.githubRepo,
      branch: config.githubBranch,
    });
    await vectorStorage.updateMetadata('statistics', {
      ...docStats,
      ...chunkStats,
    });
    console.log('✅ Metadata updated');
    
    // Step 8: Clear cache
    console.log('\n🧹 Step 8: Clearing cache...');
    cacheService.clear();
    await cacheService.saveCache();
    console.log('✅ Cache cleared');
    
    // Final statistics
    console.log('\n📈 Final Statistics:');
    const storageStats = await vectorStorage.getStorageStats();
    console.log(`   - Total chunks: ${storageStats.totalChunks}`);
    console.log(`   - Total files: ${storageStats.totalFiles}`);
    console.log(`   - Last updated: ${storageStats.lastUpdated}`);
    console.log(`   - Storage path: ${storageStats.storagePath}`);
    console.log(`   - Index size: ${(storageStats.indexSize / 1024).toFixed(2)} KB`);
    console.log(`   - Vectors size: ${(storageStats.vectorsSize / 1024 / 1024).toFixed(2)} MB`);
    
    console.log('\n✅ Reindexing completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Reindexing failed:', error.message);
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
