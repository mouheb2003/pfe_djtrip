import axios from 'axios';
import { config } from '../config/index.js';

class GitHubService {
  constructor() {
    this.baseUrl = config.githubApiUrl;
    this.token = config.githubToken;
    this.owner = config.githubOwner;
    this.repo = config.githubRepo;
    this.branch = config.githubBranch;
  }

  getHeaders() {
    const headers = {
      'Accept': 'application/vnd.github.v3+json',
    };
    
    if (this.token) {
      headers['Authorization'] = `token ${this.token}`;
    }
    
    return headers;
  }

  async getRepositoryTree(path = '') {
    try {
      const url = `${this.baseUrl}/repos/${this.owner}/${this.repo}/git/trees/${this.branch}:${path}?recursive=1`;
      const response = await axios.get(url, { headers: this.getHeaders() });
      
      if (response.data.truncated) {
        console.warn('Repository tree is truncated, fetching may be incomplete');
      }
      
      return response.data.tree;
    } catch (error) {
      console.error('Error fetching repository tree:', error.message);
      throw new Error(`Failed to fetch repository tree: ${error.message}`);
    }
  }

  async getFileContent(path) {
    try {
      const url = `${this.baseUrl}/repos/${this.owner}/${this.repo}/contents/${path}?ref=${this.branch}`;
      const response = await axios.get(url, { headers: this.getHeaders() });
      
      if (response.data.content) {
        // Decode base64 content
        const content = Buffer.from(response.data.content, 'base64').toString('utf-8');
        return {
          path: response.data.path,
          name: response.data.name,
          size: response.data.size,
          content: content,
          sha: response.data.sha,
        };
      }
      
      return null;
    } catch (error) {
      if (error.response?.status === 404) {
        console.warn(`File not found: ${path}`);
        return null;
      }
      console.error(`Error fetching file ${path}:`, error.message);
      throw new Error(`Failed to fetch file ${path}: ${error.message}`);
    }
  }

  async getMultipleFiles(paths) {
    const files = [];
    
    for (const path of paths) {
      try {
        const file = await this.getFileContent(path);
        if (file) {
          files.push(file);
        }
      } catch (error) {
        console.error(`Failed to fetch ${path}:`, error.message);
      }
    }
    
    return files;
  }

  filterDocumentationFiles(tree, basePath = '') {
    const supportedExtensions = config.supportedExtensions;
    const docsPath = config.docsPath;
    
    return tree
      .filter(item => {
        // Filter by type (files only)
        if (item.type !== 'blob') return false;
        
        // Filter by extension
        const ext = item.path.split('.').pop().toLowerCase();
        const hasSupportedExt = supportedExtensions.some(supportedExt => 
          ext === supportedExt.replace('.', '')
        );
        
        if (!hasSupportedExt) return false;
        
        // Filter by path (if docsPath is specified)
        if (docsPath && !item.path.startsWith(docsPath)) {
          // Also check for common documentation file names
          const commonDocs = ['README', 'CONTRIBUTING', 'CHANGELOG', 'LICENSE', 'INSTALL'];
          const fileName = item.path.split('/').pop().split('.')[0].toUpperCase();
          return commonDocs.includes(fileName);
        }
        
        return true;
      })
      .map(item => item.path);
  }

  async getAllDocumentationFiles() {
    try {
      console.log('Fetching repository tree...');
      const tree = await this.getRepositoryTree();
      
      console.log('Filtering documentation files...');
      const docPaths = this.filterDocumentationFiles(tree);
      
      console.log(`Found ${docPaths.length} documentation files`);
      
      return docPaths;
    } catch (error) {
      console.error('Error getting documentation files:', error.message);
      throw error;
    }
  }

  async fetchAllDocumentation() {
    try {
      const docPaths = await this.getAllDocumentationFiles();
      const files = await this.getMultipleFiles(docPaths);
      
      console.log(`Successfully fetched ${files.length} documentation files`);
      
      return files;
    } catch (error) {
      console.error('Error fetching all documentation:', error.message);
      throw error;
    }
  }

  async getRepositoryInfo() {
    try {
      const url = `${this.baseUrl}/repos/${this.owner}/${this.repo}`;
      const response = await axios.get(url, { headers: this.getHeaders() });
      
      return {
        name: response.data.name,
        description: response.data.description,
        defaultBranch: response.data.default_branch,
        updatedAt: response.data.updated_at,
        stars: response.data.stargazers_count,
        url: response.data.html_url,
      };
    } catch (error) {
      console.error('Error fetching repository info:', error.message);
      throw new Error(`Failed to fetch repository info: ${error.message}`);
    }
  }
}

export default new GitHubService();
