/**
 * Word value -> Docker host port allocator.
 *
 * The first three characters of a word are scored A=1, B=2, ... Z=26
 * (punctuation and case ignored) and the score becomes the last three digits of
 * the host port. When a port is taken by an existing compose file, the leading
 * prefix is bumped until a free port is found: 20021 -> 21021 -> 22021 -> ...
 *
 * Usage:
 *   bun scripts/calculate-port.js            # interactive
 *   bun scripts/calculate-port.js jellyfin   # one-off, prints the report
 *   bun scripts/calculate-port.js jellyfin --json
 *   bun scripts/calculate-port.js --help
 */

const fs = require('fs');
const path = require('path');
const readline = require('node:readline/promises');

const ROOT = process.cwd();

const COMPOSE_FILE = /^(docker-)?compose(\.[a-z0-9_-]+)*\.ya?ml$/i;
const SKIP_DIRS = new Set(['node_modules', '.git', 'dist', 'build', 'vendor', 'coverage']);

const MAX_PORT = 65535; // highest port Docker will bind
const BASE_PREFIX = 20; // 20xxx is the first port block
const MAX_PREFIX = Math.floor(MAX_PORT / 1000); // 65xxx, capped again per candidate
const SCORED_CHARS = 3; // only the first three characters of a word are scored

const WORD_CHARS = /[^A-Z]/g;

/** The characters that count toward the score: first three, letters only. */
const scoreChars = (input) =>
  String(input).slice(0, SCORED_CHARS).toUpperCase().replace(WORD_CHARS, '');

const wordValue = (input) => {
  const letters = scoreChars(input);
  if (!letters) return null;
  let total = 0;
  for (const letter of letters) total += letter.charCodeAt(0) - 64;
  return total;
};

const findComposeFiles = (dir) => {
  const found = [];

  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return found;
  }

  for (const entry of entries) {
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name) || entry.name.startsWith('.')) continue;
      found.push(...findComposeFiles(path.join(dir, entry.name)));
      continue;
    }

    if (entry.isFile() && COMPOSE_FILE.test(entry.name)) {
      found.push(path.join(dir, entry.name));
    }
  }

  return found;
};

/** Pull the host-side port(s) out of one compose `ports:` list entry. */
const hostPortsFromSpec = (rawSpec) => {
  let spec = String(rawSpec).replace(/\s+#.*$/, '').trim();
  if (!spec) return [];

  // Quoted string, with an optional protocol suffix inside the quotes.
  const quoted = spec.match(/^(['"])(.*)\1$/);
  if (quoted) spec = quoted[2];

  // ${PORT:-20080} -> 20080, ${PORT} -> ''
  spec = spec.replace(/\$\{[a-z0-9_]+(?::-([^}]*))?\}/gi, (_, fallback) => fallback || '');

  // Strip the protocol, then take the host field counting from the right so
  // that `127.0.0.1:20080:80` and `[::1]:20080:80` both resolve to 20080.
  spec = spec.split('/')[0].trim();
  const fields = spec.split(':');
  if (fields.length < 2) return []; // container-only port, binds a random host port

  const hostField = fields[fields.length - 2].trim();
  const range = hostField.match(/^(\d+)\s*-\s*(\d+)$/);
  if (range) return [Number(range[1]), Number(range[2])];

  const port = Number(hostField);
  return Number.isInteger(port) ? [port] : [];
};

/** Collect every host port bound under the `ports:` keys of a compose file. */
const hostPortsFromText = (text) => {
  const ports = [];
  let blockIndent = null;

  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || /^\s*#/.test(line)) continue;

    const indent = line.length - line.trimStart().length;

    const key = line.match(/^(\s*)ports\s*:\s*(.*)$/);
    if (key) {
      blockIndent = indent;

      const inline = key[2].replace(/\s+#.*$/, '').trim();
      if (inline.startsWith('[') && inline.endsWith(']')) {
        for (const item of inline.slice(1, -1).split(',')) {
          ports.push(...hostPortsFromSpec(item));
        }
        blockIndent = null;
      }
      continue;
    }

    const item = line.match(/^(\s*)-\s*(.*)$/);
    if (blockIndent === null) continue; // outside any ports block

    if (!item || indent <= blockIndent) {
      blockIndent = null; // dedent out of the ports block
      continue;
    }

    ports.push(...hostPortsFromSpec(item[2]));
  }

  return ports;
};

/** Scan every compose file and report which host ports are already claimed. */
const scanUsedPorts = (dir) => {
  const owners = new Map();

  for (const file of findComposeFiles(dir)) {
    let text;
    try {
      text = fs.readFileSync(file, 'utf8');
    } catch {
      continue;
    }

    for (const port of hostPortsFromText(text)) {
      const relative = path.relative(dir, file) || path.basename(file);
      if (!owners.has(port)) owners.set(port, relative);
    }
  }

  return owners;
};

/**
 * Keep the three-digit word score and walk the prefix upward until the port is
 * free. `20021` taken resolves to `21021`, then `22021`, and so on.
 */
const assignPort = (value, usedPorts) => {
  const suffix = String(value).padStart(3, '0');
  const blocked = [];

  for (let prefix = BASE_PREFIX; prefix <= MAX_PREFIX; prefix += 1) {
    const candidate = Number(`${prefix}${suffix}`);
    if (candidate > MAX_PORT) break; // 65xxx only reaches so far before 65535
    if (!usedPorts.has(candidate)) return { port: candidate, prefix, blocked };
    blocked.push(candidate);
  }

  return null;
};

/** Score a word and pick the lowest free port in its block. */
const resolveWord = (input, owners) => {
  const scored = scoreChars(input);
  const value = wordValue(input);

  if (value === null) {
    return { scored: '', value: null, ok: false, reason: 'That input has no letters in it.', blocked: [] };
  }

  const result = assignPort(value, owners);
  if (!result) {
    return {
      scored,
      value,
      ok: false,
      reason: `No free port left for value ${value}; every candidate from ${BASE_PREFIX}000 to ${MAX_PORT} is taken.`,
      blocked: [],
    };
  }

  return {
    scored,
    value,
    ok: true,
    port: result.port,
    prefix: result.prefix,
    blocked: result.blocked,
  };
};

/** Same as resolveWord, plus where the scan came from (used for --json). */
const buildReport = (input, root) => {
  const owners = scanUsedPorts(root);
  const resolved = resolveWord(input, owners);

  return {
    input,
    ...resolved,
    owner: resolved.ok ? owners.get(resolved.port) ?? null : null,
    usedCount: owners.size,
  };
};

const formatReport = (input, resolved) => {
  const lines = [`  word      : ${input}`];

  if (!resolved.ok) {
    lines.push(`  error     : ${resolved.reason}`);
    return lines.join('\n');
  }

  lines.push(`  scored    : ${resolved.scored} (first ${SCORED_CHARS} characters)`, `  value     : ${resolved.value}`);

  if (resolved.blocked.length) {
    lines.push(
      `  taken     : ${resolved.blocked.map((p) => `${p} (in use)`).join(', ')}`,
      `  bumped    : prefix ${BASE_PREFIX} -> ${resolved.prefix}`
    );
  }

  lines.push(`  port      : ${resolved.port}`);
  return lines.join('\n');
};

const readStdin = () =>
  new Promise((resolve) => {
    let input = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      input += chunk;
    });
    process.stdin.on('end', () => resolve(input));
  });

const rescanSummary = (root, owners) => {
  const files = findComposeFiles(root).length;
  return `Rescanned ${files} compose file${files === 1 ? '' : 's'}, ${owners.size} host port${owners.size === 1 ? '' : 's'} in use.`;
};

const printBanner = (owners, root) => {
  const files = findComposeFiles(root).length;
  console.log("Calculate a word's value");
  console.log('');
  console.log(`Scanned ${files} compose file${files === 1 ? '' : 's'}, ${owners.size} host port${owners.size === 1 ? '' : 's'} in use.`);
  console.log('');
  console.log('Enter a word to calculate its value (A=1, B=2, C=3, etc). Punctuation and case are ignored.');
  console.log(`Only the first ${SCORED_CHARS} characters are scored.`);
  console.log(`Ports are ${BASE_PREFIX}xxx upward, bumping the prefix when one is taken. "reload" rescans, "q" quits.`);
  console.log('');
};

const interactive = async (root) => {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  let owners = scanUsedPorts(root);

  printBanner(owners, root);

  for (;;) {
    let answer;
    try {
      answer = (await rl.question('word> ')).trim();
    } catch {
      break; // stdin closed
    }

    if (!answer) continue;

    const command = answer.toLowerCase();
    if (command === 'q' || command === 'quit' || command === 'exit') break;

    if (command === 'reload' || command === 'rescan') {
      owners = scanUsedPorts(root);
      console.log(rescanSummary(root, owners));
      continue;
    }

    console.log('');
    console.log(formatReport(answer, resolveWord(answer, owners)));
    console.log('');
  }

  rl.close();
};

/** Piped words (one per line) reuse the same resolver without the prompt. */
const batch = async (root) => {
  const owners = scanUsedPorts(root);
  const stdin = await readStdin();
  const words = stdin
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .filter((line) => !['q', 'quit', 'exit', 'reload', 'rescan'].includes(line.toLowerCase()));

  for (const word of words) {
    console.log('');
    console.log(formatReport(word, resolveWord(word, owners)));
  }

  if (words.length) console.log('');
};

const parseArgs = (argv) => {
  const options = { words: [], json: false, list: false, root: ROOT };
  const rest = [];

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--json') options.json = true;
    else if (arg === '--list') options.list = true;
    else if (arg === '--help' || arg === '-h') options.help = true;
    else if (arg === '--dir' || arg === '-d') options.root = path.resolve(argv[++i] || ROOT);
    else rest.push(arg);
  }

  options.words = rest;
  return options;
};

const main = async () => {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    console.log(
      [
        "Calculate a word's value and pick a free Docker host port.",
        `Only the first ${SCORED_CHARS} characters count, and ports are searched from ${BASE_PREFIX}xxx to ${MAX_PORT}.`,
        '',
        'Usage:',
        '  bun scripts/calculate-port.js                 start the interactive prompt',
        '  bun scripts/calculate-port.js <word...>       calculate without prompting',
        '  echo "a" | bun scripts/calculate-port.js      batch over piped words',
        '',
        'Options:',
        '  -d, --dir <path>   folder to scan for compose files (default: repo root)',
        '      --list         list every host port already bound in compose files',
        '      --json         emit JSON instead of text',
        '  -h, --help         show this message',
        '',
        'Interactive commands: reload (rescan compose files), q (quit)',
      ].join('\n')
    );
    return;
  }

  if (options.list) {
    const owners = scanUsedPorts(options.root);
    const files = findComposeFiles(options.root);

    if (options.json) {
      console.log(JSON.stringify({ files: files.length, ports: [...owners].map(([port, file]) => ({ port, file })) }, null, 2));
      return;
    }

    console.log(`${files.length} compose file(s), ${owners.size} host port(s) in use:`);
    for (const [port, file] of [...owners].sort((a, b) => a[0] - b[0])) {
      console.log(`  ${String(port).padStart(5)}  ${file}`);
    }
    return;
  }

  if (options.words.length) {
    const reports = options.words.map((word) => buildReport(word, options.root));

    if (options.json) {
      console.log(JSON.stringify(reports.length === 1 ? reports[0] : reports, null, 2));
      return;
    }

    for (const report of reports) {
      console.log('');
      console.log(formatReport(report.input, report));
    }
    console.log('');
    return;
  }

  if (process.stdin.isTTY) {
    await interactive(options.root);
    return;
  }

  await batch(options.root);
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});