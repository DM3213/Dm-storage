const wrap = document.getElementById('wrap');
const ownerEl = document.getElementById('owner');
const listEl = document.getElementById('list');
const input = document.getElementById('friend');
const btnAdd = document.getElementById('btnAdd');
const btnClose = document.getElementById('btnClose');

let state = { objectId: null, owner: '', list: [] };

function setVisible(v){ wrap.classList.toggle('hidden', !v); }

function hatSVG(){
  return `<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M3 19h18v-2c0-1.1-.9-2-2-2h-1.1l-2.1-7.2c-.2-.6-.7-1.1-1.3-1.3-.9-.3-1.9.2-2.2 1.1L11 8.9 9.7 5.6C9.4 4.7 8.4 4.2 7.5 4.5c-.6.2-1.1.7-1.3 1.3L4.1 15H3c-1.1 0-2 .9-2 2v2h2zm3.6-4 1.8-6.2 1.4 3.6c.2.5.6.8 1.1.8.5 0 .9-.3 1.1-.8l1.4-3.6 1.8 6.2H6.6z"/></svg>`;
}

function render(){
  ownerEl.textContent = state.owner || '';
  listEl.innerHTML = '';
  (state.list || []).forEach(cid => {
    const card = document.createElement('div'); card.className = 'card';
    const tl = document.createElement('div'); tl.className = 'corner tl';
    const tr = document.createElement('div'); tr.className = 'corner tr';
    const bl = document.createElement('div'); bl.className = 'corner bl';
    const br = document.createElement('div'); br.className = 'corner br';

    const trash = document.createElement('button'); trash.className = 'trash'; trash.innerHTML = '🗑';
    trash.title = 'Revoke'; trash.addEventListener('click', () => removeAccess(cid));

    const avatar = document.createElement('div'); avatar.className = 'avatar'; avatar.innerHTML = hatSVG();
    const cidEl = document.createElement('div'); cidEl.className = 'cid mono'; cidEl.textContent = cid;
    const meta = document.createElement('div'); meta.className = 'meta'; meta.textContent = 'whitelisted';

    const actions = document.createElement('div'); actions.className = 'actions';
    const revoke = document.createElement('button'); revoke.className = 'pill'; revoke.textContent = 'Revoke Access';
    revoke.addEventListener('click', () => removeAccess(cid));
    actions.appendChild(revoke);

    card.append(tl,tr,bl,br,trash,avatar,cidEl,meta,actions);
    listEl.appendChild(card);
  });
}

async function nui(name, data){
  const res = await fetch(`https://dm-storage/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data||{})
  });
  try { return await res.json(); } catch { return null; }
}

async function refresh(){
  if(!state.objectId) return;
  const d = await nui('storage:access:get', { objectId: state.objectId });
  if (d){ state.owner = d.owner; state.list = d.list || []; render(); }
}

async function addAccess(){
  const target = input.value.trim(); if(!target) return;
  await nui('storage:access:add', { objectId: state.objectId, target });
  input.value='';
  setTimeout(refresh, 150);
}

async function removeAccess(cid){
  await nui('storage:access:remove', { objectId: state.objectId, cid });
  setTimeout(refresh, 150);
}

btnAdd.addEventListener('click', addAccess);
btnClose.addEventListener('click', () => { nui('storage:access:close', {}); setVisible(false); });

window.addEventListener('message', (e) => {
  const { action, payload } = e.data || {};
  if(action === 'access:open'){
    console.log("here")
    state.objectId = payload.objectId; state.owner = payload.owner; state.list = payload.list || [];
    setVisible(true); render(); input.focus();
  } else if(action === 'access:update'){
    state.owner = payload.owner; state.list = payload.list || []; render();
  }
});

document.addEventListener('keydown', (e) => {
  if(e.key === 'Escape') { nui('storage:access:close', {}); setVisible(false); }
});
