import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = resolve(root, 'node_modules', 'three');
const vendorRoot = resolve(root, 'web', 'vendor', 'three');

await mkdir(resolve(vendorRoot, 'addons', 'controls'), { recursive: true });
await copyFile(
  resolve(sourceRoot, 'build', 'three.module.min.js'),
  resolve(vendorRoot, 'three.module.min.js'),
);
await copyFile(
  resolve(sourceRoot, 'build', 'three.core.min.js'),
  resolve(vendorRoot, 'three.core.min.js'),
);
const controlsSource = await readFile(
  resolve(sourceRoot, 'examples', 'jsm', 'controls', 'OrbitControls.js'),
  'utf8',
);
const browserReadyControls = controlsSource.replace(
  "} from 'three';",
  "} from '../../three.module.min.js';",
);
if (browserReadyControls === controlsSource) {
  throw new Error('Could not rewrite the OrbitControls Three.js import.');
}
await writeFile(
  resolve(vendorRoot, 'addons', 'controls', 'OrbitControls.js'),
  browserReadyControls,
);

const license = await readFile(resolve(sourceRoot, 'LICENSE'), 'utf8');
await writeFile(resolve(vendorRoot, 'LICENSE'), license);
