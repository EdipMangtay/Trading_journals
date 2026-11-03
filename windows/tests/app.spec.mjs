import { test, expect, _electron as electron } from '@playwright/test';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import os from 'node:os';

test('complete offline journal, all screens, images, backup and persistence',async({},testInfo)=>{
  test.setTimeout(180000);
  const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'journal-ui-test-'));
  const directory=path.join(temporary,'new-user','Liquidity Edge');
  await expect(fs.access(directory)).rejects.toThrow();
  const options=process.env.JOURNAL_E2E_EXECUTABLE?{executablePath:process.env.JOURNAL_E2E_EXECUTABLE,args:[]}:{args:['.']};
  const launch=()=>electron.launch({...options,env:{...process.env,JOURNAL_TEST_DATA_DIR:directory},timeout:30000});
  let app,page;const errors=[];
  const watch=()=>page.on('pageerror',error=>errors.push(error.message));
  const nav=async name=>page.locator('.nav').getByRole('button',{name,exact:true}).click();
  const press=async name=>page.getByRole('button',{name,exact:true}).click();
  try{
    app=await launch();page=await app.firstWindow();watch();
    await expect(page.getByRole('heading',{name:"Performans masası"})).toBeVisible();
    await expect(page.locator('.demo-banner')).toHaveCount(0);
    const fresh=await page.evaluate(()=>window.journal.load());
    for(const field of ['trades','setups','reviews','screenshots'])expect(fresh[field]).toEqual([]);
    await nav("İşlemler");await expect(page.locator('[data-trade]')).toHaveCount(0);
    await page.clock.install();
    await page.evaluate(()=>{
      const search=document.querySelector('#search');search.value='NQ';search.dispatchEvent(new Event('input',{bubbles:true}));
      [...document.querySelectorAll('.nav button')].find(button=>button.textContent.trim()==="Ayarlar").click();
      const timezone=document.querySelector('[name=timezone]');timezone.value='Europe/Istanbul';timezone.dispatchEvent(new Event('input',{bubbles:true}));
    });
    await page.clock.runFor(300);
    await expect(page.getByLabel("Saat dilimi",{exact:true})).toHaveValue('Europe/Istanbul');
    await page.clock.resume();
    await nav("Ayarlar");await press("Demoyu aç");await nav("Genel Bakış");
    await expect(page.locator('.demo-banner')).toBeVisible();
    await page.screenshot({path:'test-results/desktop-dashboard.png',fullPage:true});
    await page.screenshot({path:'test-results/dashboard-viewport.png'});
    expect(await page.locator('#equity').evaluate(c=>Array.from(c.getContext('2d').getImageData(0,0,c.width,c.height).data).some((v,i)=>i%4===3&&v>0))).toBe(true);
    for(const name of ["İşlemler","Takvim","Hesaplar & Risk","Araştırma Laboratuvarı","Senaryo Analizi","Günlük Plan","CSV Aktarım","Analizler","Strateji Analizi","Strateji Defteri","Hatalar","Ekran Görüntüleri","İstatistikler","Değerlendirme","Ayarlar"]){
      await nav(name);await expect(page.locator('main h1')).toBeVisible();await page.screenshot({path:`test-results/${name.toLowerCase().replaceAll(' ','-')}.png`,fullPage:true});
    }
    await nav("Genel Bakış");await page.setViewportSize({width:390,height:844});
    expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.screenshot({path:'test-results/narrow-dashboard.png',fullPage:true});
    await page.setViewportSize({width:1440,height:1000});await page.locator('.demo-banner').getByRole('button',{name:"Günlüğüme dön"}).click();
    await expect(page.locator('.demo-banner')).toHaveCount(0);
    await nav("Strateji Defteri");await press("Yeni strateji");await page.getByLabel("Strateji adı",{exact:true}).fill('Test setup');await page.getByLabel("İdeal koşullar").fill('Sweep and displacement');await press("Stratejiyi kaydet");
    await expect(page.getByRole('heading',{name:'Test setup',exact:true})).toBeVisible();
    await page.locator('.topbar').getByRole('button',{name:"Yeni işlem"}).click();
    await page.getByLabel("Strateji",{exact:true}).selectOption({label:'Test setup'});await page.getByLabel('Brüt K/Z USD',{exact:true}).fill('250');await page.getByLabel("R katsayısı",{exact:true}).fill('2');
    await page.screenshot({path:'test-results/trade-editor.png'});
    await page.getByText("Fiyatlar, risk ve süre",{exact:true}).click();await page.getByLabel("Masraflar",{exact:true}).fill('5');await page.getByLabel('Risk USD',{exact:true}).fill('100');await press("Net K/Z'den R hesapla");await expect(page.getByLabel("R katsayısı",{exact:true})).toHaveValue('2.45');
    await page.getByText("Çeyrek Teorisi · QT",{exact:true}).click();await page.getByLabel("QT etkin",{exact:true}).check();await page.getByLabel("QT modeli geçerli",{exact:true}).check();await page.getByLabel("QT yönü uyumlu",{exact:true}).check();
    await page.getByText("SSMT ve TSMO teyitleri",{exact:true}).click();await page.getByLabel("SSMT teyidi",{exact:true}).selectOption('Yes');await page.getByLabel("Geçerli SSMT",{exact:true}).check();await page.locator('#market-checklist').getByLabel('ES',{exact:true}).check();
    await page.getByText("İşlem tezi ve değerlendirme notları",{exact:true}).click();await page.getByLabel("İşlem tezi",{exact:true}).fill('Offline persistence <script>alert(1)</script>');await page.getByLabel("Temel ders",{exact:true}).fill('Wait for displacement');
    const icon=path.resolve('assets/icon.png');await app.evaluate(({dialog},file)=>{dialog.showOpenDialog=async()=>({canceled:false,filePaths:[file]});},icon);await press("Görsel ekle…");await expect(page.locator('#draft-shots img')).toHaveCount(1);
    await page.locator('#draft-shots [data-shot]').click();const viewer=page.locator('.image-dialog');await expect(viewer.locator('img')).toBeVisible();
    await expect.poll(()=>viewer.locator('img').evaluate(i=>i.naturalWidth)).toBeGreaterThan(0);
    await viewer.getByRole('button',{name:"Ok",exact:true}).click();const box=await viewer.locator('canvas').boundingBox();await page.mouse.move(box.x+box.width*.2,box.y+box.height*.2);await page.mouse.down();await page.mouse.move(box.x+box.width*.7,box.y+box.height*.7);await page.mouse.up();
    await expect(viewer.locator('.annotation-count')).toHaveText('1 işaretleme');await viewer.getByRole('button',{name:"Değerlendirmeyi kaydet",exact:true}).click();await press("İşlemi kaydet");await expect(page.locator('#editor')).not.toBeVisible();
    await nav("İşlemler");await expect(page.locator('.trade-rows')).toContainText('$245,00');await page.locator('[data-trade]').click();await press('Tam ayrıntıyı aç');await expect(page.locator('#editor')).toContainText('Offline persistence <script>alert(1)</script>');await press("İşlemi düzenle");await page.getByLabel('Brüt K/Z USD',{exact:true}).fill('999');await press("Vazgeç");await expect(page.locator('.trade-rows')).toContainText('$245,00');
    await page.getByLabel("İşlemlerde ara").fill('kurallı qt');await expect(page.locator('[data-trade]')).toHaveCount(1);await press("Sıfırla");
    await nav("Değerlendirme");await press("Yeni değerlendirme");await page.getByLabel("Ne işe yaradı?",{exact:true}).fill('Patient execution');await page.getByLabel("Sonraki dönem için tek değişikliğim ne?").fill('Patient execution');await expect(page.locator('#review-snapshot')).toContainText('$245,00');await press("Değerlendirmeyi kaydet");await expect(page.getByText('Patient execution',{exact:true})).toBeVisible();
    await nav("Ayarlar");await page.getByLabel("Saat dilimi",{exact:true}).fill('Europe/Istanbul');await press("Tercihleri kaydet");await expect(page.locator('#toast')).toHaveText("Tercihler kaydedildi.");await expect(page.getByLabel("Saat dilimi",{exact:true})).toHaveValue('Europe/Istanbul');
    const saved=await page.evaluate(()=>window.journal.load());expect(saved.preferences.timezone).toBe('Europe/Istanbul');expect(saved.trades).toHaveLength(1);expect(saved.trades[0].ssmt.markets).toEqual(['ES']);expect(saved.screenshots[0].screenshot.annotations).toHaveLength(1);expect(saved.trades[0].qt.valid).toBe(true);
    const backup=path.join(directory,'export.json');await app.evaluate(({dialog},file)=>{dialog.showSaveDialog=async()=>({canceled:false,filePath:file});},backup);await press("JSON yedeği dışa aktar");await expect.poll(async()=>{try{return JSON.parse(await fs.readFile(backup,'utf8')).trades.length;}catch{return 0;}}).toBe(1);
    await fs.copyFile(backup,'test-results/windows-backup.json');
    await app.close();app=await launch();page=await app.firstWindow();watch();await nav("İşlemler");await expect(page.locator('[data-trade]')).toHaveCount(1);await expect(page.locator('.trade-rows')).toContainText('$245,00');
    await nav("Ayarlar");await expect(page.getByLabel("Saat dilimi",{exact:true})).toHaveValue('Europe/Istanbul');await press("Demoyu aç");await nav("İşlemler");await expect(page.locator('[data-trade]')).toHaveCount(28);await page.locator('.demo-banner').getByRole('button',{name:"Günlüğüme dön"}).click();await expect(page.locator('[data-trade]')).toHaveCount(1);
    await page.locator('[data-trade]').click();await press('Tam ayrıntıyı aç');await press("Sil");await page.locator('#confirm').getByRole('button',{name:"Sil",exact:true}).click();await expect(page.locator('[data-trade]')).toHaveCount(0);
    await app.evaluate(({dialog},file)=>{dialog.showOpenDialog=async()=>({canceled:false,filePaths:[file]});dialog.showMessageBox=async()=>({response:1});},backup);await nav("Ayarlar");await press("JSON yedeğini geri yükle");await nav("İşlemler");await expect(page.locator('[data-trade]')).toHaveCount(1);
    expect(errors).toEqual([]);
  }catch(error){if(page&&!page.isClosed()){console.error('Application message:',await page.locator('#toast').textContent());await page.screenshot({path:testInfo.outputPath('failure.png')});}throw error;
  }finally{try{await app?.close();}finally{await fs.rm(temporary,{recursive:true,force:true});}}
});
