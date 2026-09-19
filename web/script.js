const resourceName = 'rsg-medic';

const partLabels = {
    head: 'Head',
    torso: 'Torso',
    left_arm: 'Left Arm',
    right_arm: 'Right Arm',
    left_leg: 'Left Leg',
    right_leg: 'Right Leg',
};

const stateLabels = {
    healthy: 'Healthy',
    injured: 'Injured',
    broken: 'Broken',
    bleeding: 'Bleeding'
};

function updateSkeleton(injuries) {
    const parts = ['head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg'];
    const extraMap = { 'head': ['neck'], 'torso': ['pelvis'] };

    for (const part of parts) {
        const state = injuries[part] || 'healthy';
        const el = document.getElementById('inj-' + part);
        if (!el) continue;

        const group = el.closest('.body-part');
        if (group) {
            group.className = 'body-part state-' + state;
        }

        if (extraMap[part]) {
            for (const extra of extraMap[part]) {
                const extraEl = document.getElementById('inj-' + extra);
                if (extraEl) {
                    const extraGroup = extraEl.closest('.body-part');
                    if (extraGroup) {
                        extraGroup.className = 'body-part state-' + state;
                    }
                }
            }
        }
    }

    const list = document.getElementById('bodyPartList');
    list.innerHTML = '';
    for (const part of parts) {
        const state = injuries[part] || 'healthy';
        const div = document.createElement('div');
        div.className = 'body-part-item state-' + state;
        div.textContent = partLabels[part] + ': ' + stateLabels[state];
        list.appendChild(div);
    }
}

function closeUI() {
    document.getElementById('skeletonOverlay').classList.add('hidden');
    fetch('https://' + resourceName + '/closeSkeleton', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(function() {});
}

function dutyFetch(action, data) {
    return fetch('https://' + resourceName + '/' + action, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).catch(function() {});
}

const DutyUI = {
    screen: 'main',
    onDuty: false,
    locName: '',
    items: [],

    esc(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },

    open(data) {
        this.onDuty = !!data.onDuty;
        this.locName = data.locName || 'Medic Office';
        this.items = data.items || [];
        this.showMain();
        document.getElementById('dutyOverlay').classList.remove('hidden');
    },

    close() {
        document.getElementById('dutyOverlay').classList.add('hidden');
        this.screen = 'main';
        dutyFetch('closeDuty', {});
    },

    setHeader(title, subtitle, back) {
        document.getElementById('dutyTitle').textContent = title;
        document.getElementById('dutySubtitle').textContent = subtitle || '';
        document.getElementById('dutyBack').style.visibility = back ? 'visible' : 'hidden';
    },

    showMain() {
        this.screen = 'main';
        this.setHeader(this.locName || 'Medic Office', 'Frontier Physician', false);
        const dutyDesc = this.onDuty ? 'Currently on duty — clock out' : 'Currently off duty — clock in';
        document.getElementById('dutyContent').innerHTML = `
            <div class="section-divider"><span>&#9670;</span></div>
            <div class="duty-card ${this.onDuty ? 'on' : ''}" id="dutyToggleCard">
                <div class="duty-card-badge"><i class="fas fa-shield-heart"></i></div>
                <div class="duty-card-body">
                    <div class="duty-card-title">Toggle Duty</div>
                    <div class="duty-card-desc">${this.esc(dutyDesc)}</div>
                </div>
                <div class="duty-card-pill">${this.onDuty ? 'On Duty' : 'Off Duty'}</div>
            </div>
            <div class="duty-card" id="dutySuppliesCard">
                <div class="duty-card-badge"><i class="fas fa-pills"></i></div>
                <div class="duty-card-body">
                    <div class="duty-card-title">Medical Supplies</div>
                    <div class="duty-card-desc">Bandages and field kits</div>
                </div>
                <div class="duty-card-arrow"><i class="fas fa-chevron-right"></i></div>
            </div>
            <div class="duty-card" id="dutyStorageCard">
                <div class="duty-card-badge"><i class="fas fa-box-open"></i></div>
                <div class="duty-card-body">
                    <div class="duty-card-title">Medic Storage</div>
                    <div class="duty-card-desc">Office stash and lockers</div>
                </div>
                <div class="duty-card-arrow"><i class="fas fa-chevron-right"></i></div>
            </div>
        `;
        document.getElementById('dutyToggleCard').addEventListener('click', () => {
            dutyFetch('dutyToggle', {});
        });
        document.getElementById('dutySuppliesCard').addEventListener('click', () => this.showSupplies());
        document.getElementById('dutyStorageCard').addEventListener('click', () => {
            this.close();
            dutyFetch('openStorage', {});
        });
    },

    showSupplies() {
        this.screen = 'supplies';
        this.setHeader('Medical Supplies', 'Free For Staff', true);
        let s = '<div class="section-divider"><span>&#9670;</span></div>';
        if (!this.items.length) {
            s += '<p class="duty-empty">No supplies stocked</p>';
        }
        this.items.forEach((item, i) => {
            const price = item.price === 0 ? 'Free' : ('$' + item.price);
            s += `
                <div class="duty-card" data-idx="${i}">
                    <div class="duty-card-badge"><i class="fas fa-pills"></i></div>
                    <div class="duty-card-body">
                        <div class="duty-card-title">${this.esc(item.label)}</div>
                        <div class="duty-card-desc">${this.esc(price)}</div>
                    </div>
                    <div class="duty-card-arrow"><i class="fas fa-chevron-right"></i></div>
                </div>
            `;
        });
        document.getElementById('dutyContent').innerHTML = s;
        document.getElementById('dutyContent').querySelectorAll('.duty-card').forEach(card => {
            card.addEventListener('click', () => {
                const item = this.items[parseInt(card.dataset.idx, 10)];
                if (item) dutyFetch('buyMedicItem', { name: item.name, price: item.price });
            });
        });
    },

    goBack() {
        if (this.screen === 'supplies') this.showMain();
        else this.close();
    }
};

document.getElementById('dutyBack').addEventListener('click', () => DutyUI.goBack());
document.getElementById('dutyClose').addEventListener('click', () => DutyUI.close());
document.getElementById('dutyLeave').addEventListener('click', () => DutyUI.close());

window.addEventListener('message', function(event) {
    if (event.data.type === 'showInjuries') {
        const overlay = document.getElementById('skeletonOverlay');
        updateSkeleton(event.data.injuries);
        document.getElementById('patientName').textContent = event.data.patientName || 'Unidentified Patient';
        overlay.classList.remove('hidden');
    } else if (event.data.type === 'showDuty') {
        DutyUI.open(event.data);
    } else if (event.data.type === 'showDutySupplies') {
        if (!document.getElementById('dutyOverlay').classList.contains('hidden')) {
            DutyUI.showSupplies();
        }
    } else if (event.data.type === 'dutyState') {
        DutyUI.onDuty = !!event.data.onDuty;
        if (!document.getElementById('dutyOverlay').classList.contains('hidden') && DutyUI.screen === 'main') {
            DutyUI.showMain();
        }
    } else if (event.data.type === 'hideDuty') {
        document.getElementById('dutyOverlay').classList.add('hidden');
    }
});

document.getElementById('closeBtn').addEventListener('click', closeUI);

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (!document.getElementById('dutyOverlay').classList.contains('hidden')) {
            DutyUI.goBack();
        } else if (!document.getElementById('skeletonOverlay').classList.contains('hidden')) {
            closeUI();
        }
    }
});

document.getElementById('skeletonOverlay').addEventListener('click', function(e) {
    if (e.target === document.getElementById('skeletonOverlay')) closeUI();
});
