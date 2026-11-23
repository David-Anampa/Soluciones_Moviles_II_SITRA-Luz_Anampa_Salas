// npm install --prefix tools/branding
// npm run generate --prefix tools/branding
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const { Resvg } = require('@resvg/resvg-js');
const root = path.resolve(__dirname, '../..');
const assets = path.join(root, 'app/assets/branding');
const res = path.join(root, 'app/android/app/src/main/res');
const write = (file, data) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, data); };
async function main() {
  const svg = fs.readFileSync(path.join(assets, 'SITRA-LUZ-icono-final.svg'), 'utf8');
  const launcher = new Resvg(svg, { fitTo: { mode: 'width', value: 1024 } }).render().asPng();
  const splash = path.join(assets, 'SITRA-LUZ-icono-final-2048.png');
  await sharp(path.join(assets, 'SITRA-LUZ-estilo-SISGET-v3.png')).trim().resize({ width: 1000, withoutEnlargement: true }).png().toFile(path.join(assets, 'logo_login.png'));
  for (const [density, scale] of [['mdpi', 1], ['hdpi', 1.5], ['xhdpi', 2], ['xxhdpi', 3], ['xxxhdpi', 4]]) {
    const icon = await sharp(launcher).resize(Math.round(40 * scale)).png().toBuffer();
    const foreground = await sharp(launcher).resize(Math.round(60 * scale)).png().toBuffer();
    const legacy = await sharp({ create: { width: Math.round(48 * scale), height: Math.round(48 * scale), channels: 4, background: '#FFFFFF' } }).composite([{ input: icon, gravity: 'centre' }]).png().toBuffer();
    write(path.join(res, `mipmap-${density}/ic_launcher.png`), legacy);
    write(path.join(res, `mipmap-${density}/ic_launcher_round.png`), legacy);
    write(path.join(res, `mipmap-${density}/ic_launcher_foreground.png`), await sharp({ create: { width: Math.round(108 * scale), height: Math.round(108 * scale), channels: 4, background: '#FFFFFF00' } }).composite([{ input: foreground, gravity: 'centre' }]).png().toBuffer());
    // La imagen queda dentro del área segura de la máscara circular de Android 12.
    const splashImage = await sharp(splash).trim().resize(Math.round(136 * scale)).png().toBuffer();
    write(path.join(res, `drawable-${density}/splash_icon.png`), await sharp({ create: { width: Math.round(288 * scale), height: Math.round(288 * scale), channels: 4, background: '#FFFFFF00' } }).composite([{ input: splashImage, gravity: 'centre' }]).png().toBuffer());
  }
}
main().catch(() => { process.stderr.write('No se pudieron generar los recursos de marca.\n'); process.exitCode = 1; });
