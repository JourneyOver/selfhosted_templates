const fs = require('fs').promises;
const path = require('path');

const ROOT = process.cwd();
const TEMPLATES_DIR = path.join(ROOT, 'templates');

const REGISTRY = {
  name: process.env.REGISTRY_NAME || "JourneyOver's Templates",
  description: process.env.REGISTRY_DESCRIPTION || 'Personal templates for selfhosted services',
  author: process.env.REGISTRY_AUTHOR || 'JourneyOver',
  url: process.env.REGISTRY_URL || 'https://github.com/JourneyOver/selfhosted_templates',
};

const PUBLIC_BASE = process.env.PUBLIC_BASE || 'https://raw.githubusercontent.com/JourneyOver/selfhosted_templates/main/templates';
const DOCS_BASE = process.env.DOCS_BASE || `${REGISTRY.url}/tree/main/templates`;
const SCHEMA_URL = process.env.SCHEMA_URL || 'https://raw.githubusercontent.com/getarcaneapp/templates/main/schema.json';

const BUMP_PART = (process.env.BUMP_PART || 'minor').toLowerCase();

const exists = async (filePath) => !!(await fs.stat(filePath).catch(() => null));

const toSlug = (inputString) =>
  inputString
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, '-')
    .replace(/--+/g, '-')
    .replace(/^-+|-+$/g, '');

function bumpSemver(version, bumpType = 'minor') {
  const match = String(version).match(/^(\d+)\.(\d+)\.(\d+)(?:[.-].*)?$/);
  if (!match) return '1.0.0';
  let [major, minor, patch] = match.slice(1).map((n) => parseInt(n, 10));
  if (bumpType === 'major') {
    major += 1;
    minor = 0;
    patch = 0;
  } else if (bumpType === 'patch') {
    patch += 1;
  } else {
    minor += 1;
    patch = 0;
  }
  return `${major}.${minor}.${patch}`;
}

async function readPrevRegistry() {
  const registryPath = path.join(ROOT, 'registry.json');
  if (!(await exists(registryPath))) return null;
  try {
    return JSON.parse(await fs.readFile(registryPath, 'utf8'));
  } catch {
    return null;
  }
}

async function build() {
  const previousRegistry = await readPrevRegistry();

  const directoryEntries = await fs.readdir(TEMPLATES_DIR, { withFileTypes: true });
  const templateDirectoryNames = directoryEntries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);

  const templateList = [];
  for (const directoryName of templateDirectoryNames) {
    const templateId = toSlug(directoryName);
    const templateDirectory = path.join(TEMPLATES_DIR, directoryName);

    // required metadata
    const metadataPath = path.join(templateDirectory, 'template.json');
    if (!(await exists(metadataPath))) {
      throw new Error(`Missing ${path.relative(ROOT, metadataPath)} (required)`);
    }
    const metadata = JSON.parse(await fs.readFile(metadataPath, 'utf8'));

    // required files and URLs
    const composeFileCandidates = ['compose.yaml', 'docker-compose.yml', 'docker-compose.yaml', 'compose.yml'];
    let composeFileName = null;
    for (const candidate of composeFileCandidates) {
      if (await exists(path.join(templateDirectory, candidate))) {
        composeFileName = candidate;
        break;
      }
    }
    if (!composeFileName) {
      throw new Error(`No compose file found in templates/${directoryName} (looked for ${composeFileCandidates.join(', ')})`);
    }
    const envExamplePath = path.join(templateDirectory, '.env.example');
    if (!(await exists(envExamplePath))) {
      throw new Error(`Missing templates/${directoryName}/.env.example`);
    }

    const templateItem = {
      id: templateId,
      name: String(metadata.name || ''),
      description: String(metadata.description || ''),
      version: String(metadata.version || ''),
      author: String(metadata.author || ''),
      compose_url: `${PUBLIC_BASE}/${templateId}/${composeFileName}`,
      env_url: `${PUBLIC_BASE}/${templateId}/.env.example`,
      documentation_url: `${DOCS_BASE}/${templateId}`,
      tags: Array.isArray(metadata.tags) ? metadata.tags.map(String) : [],
    };

    // quick checks for schema-required fields
    for (const requiredField of ['name', 'description', 'version', 'author']) {
      if (!templateItem[requiredField] || typeof templateItem[requiredField] !== 'string') {
        throw new Error(`templates/${directoryName}/template.json missing/invalid "${requiredField}"`);
      }
    }
    if (!Array.isArray(templateItem.tags) || templateItem.tags.length === 0) {
      throw new Error(`templates/${directoryName}/template.json must include non-empty "tags"`);
    }

    templateList.push(templateItem);
  }

  // Determine version bump (only when new template IDs appear)
  const previousIds = new Set((previousRegistry?.templates || []).map((template) => template.id));
  const newIds = templateList.map((template) => template.id).filter((id) => !previousIds.has(id));
  const baseVersion = previousRegistry?.version || process.env.REGISTRY_VERSION || '1.0.0';
  const nextVersion = newIds.length > 0 ? bumpSemver(String(baseVersion), BUMP_PART) : String(baseVersion);

  if (newIds.length > 0) {
    console.log(`Detected ${newIds.length} new template(s): ${newIds.join(', ')} -> bumping ${BUMP_PART} to ${nextVersion}`);
  } else {
    console.log(`No new templates detected -> keeping version ${baseVersion}`);
  }

  const registryData = {
    $schema: SCHEMA_URL,
    name: previousRegistry?.name ?? REGISTRY.name,
    description: previousRegistry?.description ?? REGISTRY.description,
    author: previousRegistry?.author ?? REGISTRY.author,
    url: previousRegistry?.url ?? REGISTRY.url,
    version: nextVersion,
    templates: templateList.sort((a, b) => a.id.localeCompare(b.id)),
  };

  const outputPath = path.join(ROOT, 'registry.json');
  let json = JSON.stringify(registryData, null, 2);
  json = json.replace(/"tags": \[([\s\S]*?)\]/g, (match, inner) => {
    const items = inner.match(/"[^"]*"/g) || [];
    return '"tags": [' + items.join(',') + ']';
  });
  await fs.writeFile(outputPath, json + '\n', 'utf8');

  console.log(`Generated registry.json with ${templateList.length} templates`);
}

build().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});