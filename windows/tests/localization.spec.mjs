import { test, expect, _electron as electron } from '@playwright/test';
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import translations from '../shared/tr.json' with { type: 'json' };

test('Turkish labels, independent dashboard, native defaults and clean layout', async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'journal-turkish-'));
  const options = process.env.JOURNAL_E2E_EXECUTABLE ? { executablePath: process.env.JOURNAL_E2E_EXECUTABLE, args: [] } : { args: ['.'] };
  const app = await electron.launch({ ...options, env: { ...process.env, JOURNAL_TEST_DATA_DIR: directory } });
  try {
    const page = await app.firstWindow();
    await expect(page.getByRole('heading', { name: 'Performans masası' })).toBeVisible();
    const nav = name => page.locator(`[data-view="${name}"]`).click();
    await nav('Settings'); await page.locator('[data-action="demo"]').click();
    const untranslated = [];
    for (const name of ['Dashboard', 'Trades', 'Calendar', 'Analytics', 'Setup Analysis', 'Playbook', 'Mistakes', 'Screenshots', 'Statistics', 'Review', 'Settings']) {
      await nav(name);
      const texts = await page.evaluate(() => {
        const walker = document.createTreeWalker(document.querySelector('#app'), NodeFilter.SHOW_TEXT), texts = [];
        while (walker.nextNode()) {
          const node = walker.currentNode;
          if (node.parentElement.getClientRects().length && !node.parentElement.closest('.model-head,.read-note')) texts.push(node.textContent.trim());
        }
        return texts;
      });
      untranslated.push(...texts.filter(value => translations[value] && translations[value] !== value && value !== 'LIQUIDITY').map(text => `${name}: ${text}`));
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
      await page.screenshot({ path: `test-results/tr-${name.replaceAll(' ', '-')}.png`, fullPage: true });
    }
    await nav('Trades'); await page.getByLabel('İşlemlerde ara').fill('not-a-real-instrument');
    await expect(page.locator('[data-trade]')).toHaveCount(0);
    await nav('Dashboard'); await expect(page.locator('#equity')).toBeVisible();
    await expect.poll(() => page.evaluate(() => scrollY)).toBe(0);
    await page.screenshot({ path: 'test-results/tr-dashboard-viewport.png' });
    await page.locator('.topbar [data-action="new-trade"]').click();
    await page.getByText('Fiyatlar, risk ve süre', { exact: true }).click();
    await expect(page.getByLabel('Risk USD', { exact: true })).toHaveValue('250');
    await page.locator('[data-action="close-editor"]').click();
    await nav('Settings'); await page.locator('[name="theme"]').selectOption('Light');
    await page.getByRole('button', { name: 'Tercihleri kaydet', exact: true }).click();
    await nav('Dashboard'); await expect(page.locator('html')).toHaveClass(/light/);
    await page.screenshot({ path: 'test-results/tr-dashboard-light.png' });
    expect([...new Set(untranslated)]).toEqual([]);
  } finally { await app.close(); await fs.rm(directory, { recursive: true, force: true }); }
});
