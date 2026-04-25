// scripts/increment-version.js
const fs = require('fs');
const path = require('path');

const packagePath = path.join(process.cwd(), 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));

// Parse current version
const versionParts = packageJson.version.split('.');
let major = parseInt(versionParts[0]);
let minor = parseInt(versionParts[1]);
let patch = parseInt(versionParts[2]);

// Increment patch version
patch++;

packageJson.version = `${major}.${minor}.${patch}`;

// Write back to package.json
fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2));

console.log(`Ã¢Å“â€¦ Version incremented to: ${packageJson.version}`);



