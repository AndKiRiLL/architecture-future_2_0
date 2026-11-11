// Подготовка AOE 4: исправленная сборка Next.js и локальный Roboto.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const builder = path.join(root, '.techradar');
const source = path.join(root, 'node_modules', 'aoe_technology_radar');
const lock = path.join(__dirname, 'generator-package-lock.json');
const digest = (value) => crypto.createHash('sha256').update(value).digest('hex');
const packageHash = digest(fs.readFileSync(path.join(root, 'package.json')));
const signature = () => digest(Buffer.concat([
  fs.readFileSync(__filename),
  fs.existsSync(lock) ? fs.readFileSync(lock) : Buffer.alloc(0),
  Buffer.from(packageHash)
]));
const marker = path.join(builder, '.future-setup');

if (!fs.existsSync(marker) || fs.readFileSync(marker, 'utf8') !== signature() ||
    !fs.existsSync(path.join(builder, 'node_modules', 'next', 'package.json'))) {
  // .techradar — только генерируемый кеш; исходные карточки находятся в radar/.
  fs.rmSync(builder, { recursive: true, force: true });
  fs.cpSync(source, builder, { recursive: true });
  const pkgPath = path.join(builder, 'package.json');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  Object.assign(pkg.devDependencies, {
    next: '15.5.29',
    'eslint-config-next': '15.5.29',
    '@fontsource/roboto': '5.3.0',
    '@svgr/cli': '8.1.0'
  });
  fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
  const hasLock = fs.existsSync(lock);
  if (hasLock) fs.copyFileSync(lock, path.join(builder, 'package-lock.json'));

  const layoutPath = path.join(builder, 'src', 'components', 'Layout', 'Layout.tsx');
  const layout = fs.readFileSync(layoutPath, 'utf8')
    .replace('import { Roboto } from "next/font/google";\n', '')
    .replace('const font = Roboto({ weight: ["400", "700"], subsets: ["latin"] });\n', '')
    .replace('styles.layout, font.className, styles[layoutClass]', 'styles.layout, styles[layoutClass]');
  fs.writeFileSync(layoutPath, layout);
  const appPath = path.join(builder, 'src', 'pages', '_app.tsx');
  fs.writeFileSync(appPath,
    'import "@fontsource/roboto/400.css";\nimport "@fontsource/roboto/700.css";\n' +
    fs.readFileSync(appPath, 'utf8'));

  const configPath = path.join(builder, 'next.config.js');
  fs.writeFileSync(configPath, fs.readFileSync(configPath, 'utf8').replace(
    'const nextConfig = {',
    'const nextConfig = {\n  outputFileTracingRoot: __dirname,\n  devIndicators: false,'
  ));

  const install = spawnSync(process.platform === 'win32' ? 'npm.cmd' : 'npm',
    [hasLock ? 'ci' : 'install', '--no-fund'], {
      cwd: builder, stdio: 'inherit', shell: process.platform === 'win32',
      env: { ...process.env, HUSKY: '0' }
    });
  if (install.error) throw install.error;
  if (install.status !== 0) process.exit(install.status || 1);
  if (!hasLock) fs.copyFileSync(path.join(builder, 'package-lock.json'), lock);
  fs.writeFileSync(marker, signature());
}
// Этот hash использует стандартный CLI AOE, чтобы переиспользовать подготовленный кеш.
fs.writeFileSync(path.join(builder, 'hash'), packageHash);
