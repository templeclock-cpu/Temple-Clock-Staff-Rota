// Quick payroll API test
const http = require('http');
const BASE = 'http://localhost:5000/api';
let token = '';
let payrollId = '';

// Dynamic far-future month so re-runs don't hit already-finalized records
const _runSec = Math.floor(Date.now() / 1000) % 9000;
const _testYear = 2050 + _runSec;
const testMonth = `${_testYear}-03`;

function req(method, path, body, tok) {
    return new Promise((resolve, reject) => {
        const url = new URL(BASE + path);
        const opts = {
            hostname: url.hostname, port: url.port,
            path: url.pathname + url.search, method,
            headers: { 'Content-Type': 'application/json' },
        };
        if (tok) opts.headers['Authorization'] = `Bearer ${tok}`;
        const r = http.request(opts, res => {
            let d = ''; res.on('data', c => d += c);
            res.on('end', () => {
                try { resolve({ s: res.statusCode, b: JSON.parse(d) }); }
                catch { resolve({ s: res.statusCode, b: d }); }
            });
        });
        r.on('error', reject);
        if (body) r.write(JSON.stringify(body));
        r.end();
    });
}

async function run() {
    console.log('\n💰 Payroll API Tests\n' + '='.repeat(40));

    // Login
    let r = await req('POST', '/auth/login', { email: 'admin@careshift.co.uk', password: 'Admin@123' });
    token = r.b.token;
    console.log(r.s === 200 ? '  ✅ Admin login' : '  ❌ Login failed');

    // Generate payroll
    r = await req('POST', '/payroll/generate', { month: testMonth }, token);
    console.log(r.s === 201 ? `  ✅ Generate payroll (${r.b.count} records)` : `  ❌ Generate: ${r.s} ${r.b.message || ''}`);

    // List payroll
    r = await req('GET', `/payroll?month=${testMonth}`, null, token);
    console.log(r.s === 200 ? `  ✅ List payroll (${r.b.length} records)` : `  ❌ List: ${r.s}`);
    if (r.b.length > 0) {
        const draft = r.b.find(rec => rec.status !== 'finalized');
        payrollId = draft ? draft._id : '';
    }

    // Adjust
    if (payrollId) {
        r = await req('PUT', `/payroll/${payrollId}/adjust`, { description: 'Night shift bonus', amount: 50 }, token);
        console.log(r.s === 200 ? `  ✅ Adjust payroll (finalPay=${r.b.finalPay})` : `  ❌ Adjust: ${r.s} ${r.b.message || ''}`);

        // Finalize
        r = await req('PUT', `/payroll/${payrollId}/finalize`, null, token);
        console.log(r.s === 200 ? `  ✅ Finalize payroll (status=${r.b.status})` : `  ❌ Finalize: ${r.s} ${r.b.message || ''}`);

        // Can't adjust after finalize
        r = await req('PUT', `/payroll/${payrollId}/adjust`, { description: 'test', amount: 10 }, token);
        console.log(r.s === 403 ? '  ✅ Blocked adjust after finalize' : `  ❌ Should block: ${r.s}`);
    }

    // Staff can't access payroll
    r = await req('POST', '/auth/login', { email: 'staff@careshift.co.uk', password: 'Staff@123' });
    const staffTok = r.b.token;
    r = await req('GET', `/payroll?month=${testMonth}`, null, staffTok);
    console.log(r.s === 403 ? '  ✅ Staff blocked from payroll' : `  ❌ Staff access: ${r.s}`);

    console.log('\n' + '='.repeat(40) + '\n');
    process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
