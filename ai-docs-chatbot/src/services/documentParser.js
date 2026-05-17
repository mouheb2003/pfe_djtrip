import MarkdownIt from 'markdown-it';

const md = new MarkdownIt({
  html: false,
  linkify: true,
  typographer: true,
});

class DocumentParser {
  constructor() {
    this.supportedExtensions = ['.md', '.txt', '.dart', '.js', '.json', '.MD', '.TXT'];
  }

  isSupportedFile(filename) {
    const ext = filename.toLowerCase().split('.').pop();
    return this.supportedExtensions.includes(`.${ext}`);
  }

  parseMarkdown(content) {
    try {
      const html = md.render(content);
      return this.extractTextFromHtml(html);
    } catch (error) {
      console.error('Error parsing markdown:', error.message);
      return content; // Return raw content if parsing fails
    }
  }

  extractTextFromHtml(html) {
    // Remove HTML tags and get plain text
    let text = html
      .replace(/<[^>]*>/g, ' ') // Remove HTML tags
      .replace(/\s+/g, ' ') // Normalize whitespace
      .trim();
    
    return text;
  }

  parsePlainText(content) {
    return content.trim();
  }

  extractMetadata(content, filename) {
    const metadata = {
      filename,
      title: filename,
      sections: [],
      headings: [],
    };

    // Extract title from first heading or filename
    const headingMatch = content.match(/^#\s+(.+)$/m);
    if (headingMatch) {
      metadata.title = headingMatch[1].trim();
    }

    // Extract all headings
    const headingRegex = /^(#{1,6})\s+(.+)$/gm;
    let match;
    while ((match = headingRegex.exec(content)) !== null) {
      const level = match[1].length;
      const text = match[2].trim();
      metadata.headings.push({ level, text });
    }

    // Extract sections based on headings
    const sections = content.split(/^#{1,6}\s+.+$/gm);
    const sectionHeadings = content.match(/^#{1,6}\s+.+$/gm) || [];
    
    metadata.sections = sectionHeadings.map((heading, index) => ({
      heading: heading.replace(/^#{1,6}\s+/, '').trim(),
      content: sections[index + 1] || '',
    }));

    return metadata;
  }

  cleanContent(content, isCode = false) {
    if (isCode) {
      // For code files, we want to keep the content but maybe normalize whitespace slightly
      return content.replace(/\s+/g, ' ').trim();
    }

    // Remove code blocks
    let cleaned = content.replace(/```[\s\S]*?```/g, '[CODE BLOCK]');
    
    // Remove inline code
    cleaned = cleaned.replace(/`[^`]+`/g, '[CODE]');
    
    // Remove URLs
    cleaned = cleaned.replace(/https?:\/\/[^\s]+/g, '[URL]');
    
    // Remove email addresses
    cleaned = cleaned.replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, '[EMAIL]');
    
    // Normalize whitespace
    cleaned = cleaned.replace(/\s+/g, ' ').trim();
    
    return cleaned;
  }

  parse(file) {
    const { name, path, content } = file;
    const ext = name.split('.').pop().toLowerCase();
    const isCode = ['dart', 'js', 'json'].includes(ext);

    let parsedContent;
    
    if (ext === 'md') {
      parsedContent = this.parseMarkdown(content);
    } else {
      parsedContent = this.parsePlainText(content);
    }

    const metadata = this.extractMetadata(content, name);
    const cleanedContent = this.cleanContent(parsedContent, isCode);

    return {
      path,
      filename: name,
      title: metadata.title,
      headings: metadata.headings,
      sections: metadata.sections,
      content: cleanedContent,
      rawContent: content,
      size: content.length,
    };
  }

  parseMultiple(files) {
    const parsedFiles = [];
    
    for (const file of files) {
      try {
        const parsed = this.parse(file);
        parsedFiles.push(parsed);
      } catch (error) {
        console.error(`Error parsing file ${file.name}:`, error.message);
      }
    }
    
    return parsedFiles;
  }

  extractCodeBlocks(content) {
    const codeBlocks = [];
    const regex = /```(\w*)\n([\s\S]*?)```/g;
    let match;
    
    while ((match = regex.exec(content)) !== null) {
      codeBlocks.push({
        language: match[1] || 'text',
        code: match[2],
      });
    }
    
    return codeBlocks;
  }

  extractTables(content) {
    const tables = [];
    const regex = /\|(.+)\|\n\|[-\s]+\|\n(\|.+?\|)+/g;
    let match;
    
    while ((match = regex.exec(content)) !== null) {
      tables.push(match[0]);
    }
    
    return tables;
  }

  extractLinks(content) {
    const links = [];
    const regex = /\[([^\]]+)\]\(([^)]+)\)/g;
    let match;
    
    while ((match = regex.exec(content)) !== null) {
      links.push({
        text: match[1],
        url: match[2],
      });
    }
    
    return links;
  }
}

export default new DocumentParser();
