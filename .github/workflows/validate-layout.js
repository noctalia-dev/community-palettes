#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.join(__dirname, '..', '..');

function findLayoutErrors(rootDir = ROOT_DIR) {
  const errors = [];
  const entries = fs.readdirSync(rootDir, { withFileTypes: true });

  for (const entry of entries) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) continue;

    const paletteDir = path.join(rootDir, entry.name);
    const jsonFiles = fs.readdirSync(paletteDir, { withFileTypes: true })
      .filter((item) => item.isFile() && path.extname(item.name) === '.json')
      .map((item) => item.name);
    const expectedFile = `${entry.name}.json`;

    if (!/^\p{Lu}/u.test(entry.name)) {
      errors.push(`${entry.name}: palette names must begin with an uppercase letter`);
    }
    if (jsonFiles.length !== 1) {
      errors.push(`${entry.name}: expected exactly one JSON file, found ${jsonFiles.length}`);
    } else if (jsonFiles[0] !== expectedFile) {
      errors.push(`${entry.name}: expected ${expectedFile}, found ${jsonFiles[0]}`);
    }
  }

  return errors;
}

function assertValidPaletteLayout(rootDir = ROOT_DIR) {
  const errors = findLayoutErrors(rootDir);
  if (errors.length === 0) return;

  console.error('Invalid palette layout:');
  for (const error of errors) console.error(`- ${error}`);
  throw new Error(`${errors.length} palette layout violation${errors.length === 1 ? '' : 's'}`);
}

if (require.main === module) {
  try {
    assertValidPaletteLayout(process.argv[2] ? path.resolve(process.argv[2]) : ROOT_DIR);
    console.log('Palette layout is valid.');
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

module.exports = { findLayoutErrors, assertValidPaletteLayout };
