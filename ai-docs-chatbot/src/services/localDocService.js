import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '../../..');

class LocalDocService {
  generateHash(content) {
    return crypto.createHash('sha256').update(content).digest('hex');
  }

  async fetchAllDocumentation() {
    console.log('Searching for documentation and source files in project root...');
    const files = [];
    
    // Extensions to index
    const supportedExtensions = ['.md', '.dart', '.js', '.json', '.txt'];
    const excludedDirs = ['node_modules', '.git', 'build', '.dart_tool', 'dist', 'ios', 'android', 'macos', 'windows', 'linux', 'data', 'cache', 'vectors', 'uploads'];
    const excludedFiles = ['package-lock.json', 'yarn.lock', '.DS_Store', 'Thumbs.db', 'COMPARISON_ANALYSIS.json'];

    const scanDirectory = async (dirPath, relativePath = '') => {
      try {
        const entries = await fs.readdir(dirPath, { withFileTypes: true });
        
        for (const entry of entries) {
          const entryName = entry.name;
          const fullPath = path.join(dirPath, entryName);
          const currentRelPath = relativePath ? path.join(relativePath, entryName) : entryName;

          if (entry.isDirectory()) {
            if (!excludedDirs.includes(entryName)) {
              await scanDirectory(fullPath, currentRelPath);
            }
          } else if (entry.isFile()) {
            const ext = path.extname(entryName).toLowerCase();
            if (supportedExtensions.includes(ext) && !excludedFiles.includes(entryName)) {
              try {
                const content = await fs.readFile(fullPath, 'utf-8');
                const stats = await fs.stat(fullPath);
                
                files.push({
                  path: currentRelPath,
                  name: entryName,
                  size: stats.size,
                  content: content,
                  hash: this.generateHash(content),
                  lastModified: stats.mtime.toISOString()
                });
                // Only log important files or summarized progress to avoid clutter
                if (ext === '.md' || files.length % 50 === 0) {
                  console.log(`✅ Indexed: ${currentRelPath}`);
                }
              } catch (err) {
                console.error(`❌ Error reading ${fullPath}:`, err.message);
              }
            }
          }
        }
      } catch (error) {
        console.error(`❌ Error scanning directory ${dirPath}:`, error.message);
      }
    };

    // Start scanning from project root
    await scanDirectory(projectRoot);

    console.log(`\n📋 Total files indexed: ${files.length}`);
    return files;
  }
}

export default new LocalDocService();
