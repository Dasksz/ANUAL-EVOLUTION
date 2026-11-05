const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('src/js/app.js', 'utf8');
const section = (start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));

function setup(error = null) {
    const nodes = new Map();
    function el(id) {
        if (!nodes.has(id)) {
            const classes = new Set();
            nodes.set(id, { value: '', textContent: '', disabled: false, handlers: {},
                classList: { add: (...xs) => xs.forEach(x => classes.add(x)), remove: (...xs) => xs.forEach(x => classes.delete(x)), contains: x => classes.has(x) },
                addEventListener(type, fn) { this.handlers[type] = fn; },
                querySelector(selector) { return selector === '.btn-text' ? null : el(id + '-button'); },
                reset() { this.wasReset = true; }
            });
        }
        return nodes.get(id);
    }
    const calls = [], toasts = [];
    let notify;
    const context = vm.createContext({
        document: { getElementById: el, addEventListener() {} },
        window: { location: { origin: 'https://dasksz.github.io', pathname: '/ANUAL-EVOLUTION/' }, showToast: (...args) => toasts.push(args) },
        supabase: { from() { throw Error('No profile lookup before authentication'); }, auth: {
            onAuthStateChange: fn => { notify = fn; },
            resetPasswordForEmail: async (...args) => { calls.push(args); return { error }; },
            updateUser: async args => { calls.push(args); return { error }; },
            getSession: async () => ({ data: { session: { user: { id: 'test' } } } })
        } },
        formForgot: el('forgotForm'), loginFormSignin: el('view-login'), loginFormReset: el('view-reset'),
        showScreen: id => calls.push(['screen', id]), switchAuthView: view => calls.push(['view', view]),
        planningPanel: { deactivate() {} }, commercialHealthPanel: { deactivate() {} },
        setElementLoading: (text, btn) => { btn.disabled = true; return 'original'; },
        restoreElementState: (text, btn) => { btn.disabled = false; },
        setTimeout: fn => fn(), localStorage: { getItem: () => null }, console
    });
    vm.runInContext('let isRecoveringPassword = false; let isAppReady = false; let checkProfileLock = false; function checkProfileStatus(user) { if (isRecoveringPassword) return; profileCalls++; } let profileCalls = 0;', context);
    vm.runInContext(section('    async function checkSession()', '    function updateProfileMenu'), context);
    vm.runInContext(section('    if (formForgot) {', '    const handleLogout'), context);
    context.checkSession();
    return { context, calls, toasts, el, notify: (...args) => notify(...args) };
}

test('recovery while signed out preserves the project path without querying profiles', async () => {
    const s = setup(); s.el('forgot-email').value = ' person@example.com ';
    await s.el('forgotForm').handlers.submit({ preventDefault() {} });
    const request = s.calls.find(c => c[0] === 'person@example.com');
    assert.equal(request[1].redirectTo, 'https://dasksz.github.io/ANUAL-EVOLUTION/');
    assert.equal(s.toasts.at(-1)[0], 'success');
    assert.equal(s.el('forgotForm-button').disabled, false);
});

test('mail service errors are shown and permit retry', async () => {
    const s = setup({ message: 'SMTP failure' });
    await s.el('forgotForm').handlers.submit({ preventDefault() {} });
    assert.equal(s.toasts.at(-1)[0], 'error');
    assert.equal(s.el('forgotForm-button').disabled, false);
});

test('recovery shows the new password form and suppresses normal session routing', () => {
    const s = setup(); s.notify('PASSWORD_RECOVERY', { user: { id: 'test' } });
    assert.equal(s.calls.at(-1)[1], s.el('view-reset'));
    s.notify('TOKEN_REFRESHED', { user: { id: 'test' } });
    assert.equal(vm.runInContext('profileCalls', s.context), 0);
    // The real profile function must also stop before accessing its cache or database.
    vm.runInContext(section('    async function checkProfileStatus(user)', '    let statusListener'), s.context);
    return s.context.checkProfileStatus({ id: 'test' });
});

test('successful password update resumes profile verification', async () => {
    const s = setup(); s.notify('PASSWORD_RECOVERY', { user: { id: 'test' } });
    s.el('reset-password').value = s.el('reset-password-confirm').value = 'Example-Password1!';
    await s.el('resetForm').handlers.submit({ preventDefault() {} });
    assert.equal(s.calls.find(c => c.password)?.password, 'Example-Password1!');
    assert.equal(vm.runInContext('isRecoveringPassword', s.context), false);
    assert.equal(vm.runInContext('profileCalls', s.context), 1);
    assert.equal(s.el('resetForm').wasReset, true);
});

test('rejected passwords keep recovery open and mismatches never call updateUser', async () => {
    const s = setup({ message: 'Password rejected' }); s.notify('PASSWORD_RECOVERY', { user: { id: 'test' } });
    s.el('reset-password').value = s.el('reset-password-confirm').value = 'Example-Password1!';
    await s.el('resetForm').handlers.submit({ preventDefault() {} });
    assert.equal(vm.runInContext('isRecoveringPassword', s.context), true);
    assert.equal(vm.runInContext('profileCalls', s.context), 0);
    const before = s.calls.length;
    s.el('reset-password-confirm').value = 'different';
    await s.el('resetForm').handlers.submit({ preventDefault() {} });
    assert.equal(s.calls.length, before);
    assert.equal(s.el('resetForm-button').disabled, false);
});
