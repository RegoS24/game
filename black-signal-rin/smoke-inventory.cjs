const assert=require('node:assert/strict');
const path=require('node:path');
const {chromium}=require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 try{
 const page=await browser.newPage({viewport:{width:1280,height:720}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('file://'+path.resolve('app/src/main/assets/index.html'));await page.click('#new');await page.locator('#dialogChoices button').first().click();
 await page.keyboard.press('i');await page.waitForSelector('.invMode');
 const pick=async id=>page.locator('[data-inv-action="pick"][data-a="'+id+'"]').click();
 await pick('start-smg');await pick('start-vest');await pick('start-optic');await pick('start-pack');await pick('start-ammo');
 let state=await page.evaluate(()=>({slots:S.slots,gear:S.gear,capacity:capacity(),reserve:S.reserve.light,mod:S.modBag.optic}));
 assert.equal(state.slots[0],'smg');assert.equal(state.slots[2],'pistol');assert.equal(state.gear.vest,true);assert.equal(state.capacity,150);assert.equal(state.reserve,144);assert.equal(state.mod,1);
 await page.locator('[data-inv-action="equip"][data-a="smg"]').click();await page.locator('[data-inv-action="attach"][data-a="optic"]').click();
 assert.equal(await page.evaluate(()=>S.mods.smg.optic),true);assert.ok(await page.evaluate(()=>weaponStats('smg').spread<weapons.smg.spread));
 await page.locator('[data-inv-action="detach"][data-a="optic"]').click();assert.equal(await page.evaluate(()=>S.modBag.optic),1);
 await page.locator('[data-inv-action="attach"][data-a="optic"]').click();
 await page.screenshot({path:'inventory-desktop.png'});
 await page.keyboard.press('i');assert.equal(await page.locator('#menuOverlay').evaluate(e=>e.classList.contains('show')),false);
 await page.evaluate(()=>{S.ammo=0;S.reserve.light=5;doReload();reload=.001;update(.02)});
 assert.deepEqual(await page.evaluate(()=>[S.ammo,S.reserve.light]),[5,0]);
 await page.keyboard.press('i');await page.locator('[data-inv-action="stashGun"][data-a="smg"]').click();assert.equal(await page.evaluate(()=>S.slots[0]),null);
 await page.locator('[data-inv-action="assign"][data-a="smg"][data-b="1"]').click();assert.equal(await page.evaluate(()=>S.slots[1]),'smg');
 await page.locator('[data-inv-action="equip"][data-a="smg"]').click();
 await page.locator('[data-inv-action="dropGun"][data-a="smg"]').click();
 assert.equal(await page.evaluate(()=>S.owned.includes('smg')),false);
 const dropId=await page.evaluate(()=>S.ground.find(x=>x.kind==='weapon'&&x.key==='smg').id);await pick(dropId);assert.equal(await page.evaluate(()=>S.mags.smg),5);
 await page.evaluate(()=>{S.hp=50;S.kits=3});await page.locator('[data-inv-action="heal"]').click();assert.equal(await page.evaluate(()=>S.hp),100);assert.equal(await page.evaluate(()=>S.kits),2);
 await page.evaluate(()=>save());await page.reload();await page.click('#continue');await page.keyboard.press('i');assert.equal(await page.evaluate(()=>S.gear.vest),true);assert.ok(await page.evaluate(()=>S.owned.includes('smg')));
 const mobile=await browser.newPage({viewport:{width:844,height:390},isMobile:true,hasTouch:true});mobile.on('pageerror',e=>errors.push(e.message));await mobile.goto('file://'+path.resolve('app/src/main/assets/index.html'));await mobile.tap('#new');await mobile.locator('#dialogChoices button').first().tap();await mobile.tap('#arsenalQuick');await mobile.waitForSelector('.invMode');
 await mobile.locator('[data-inv-action="pick"][data-a="start-smg"]').tap();assert.equal(await mobile.evaluate(()=>S.slots[0]),'smg');
 await mobile.locator('[data-inv-action="pick"][data-a="start-vest"]').tap();await mobile.locator('[data-inv-action="pick"][data-a="start-pack"]').tap();await mobile.screenshot({path:'inventory-mobile.png'});
 const widths=await mobile.evaluate(()=>({scroll:document.documentElement.scrollWidth,width:innerWidth,cols:document.querySelector('.invCols').children.length}));assert.equal(widths.scroll,widths.width);assert.equal(widths.cols,3);
 assert.deepEqual(errors,[]);console.log('PASS: inventory, loot, slots, armor, attachments, partial reload, drop/pickup, save and touch');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
