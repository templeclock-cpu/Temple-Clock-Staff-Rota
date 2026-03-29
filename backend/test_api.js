// test_api.js — Comprehensive API test suite for CareShift
// Run: node test_api.js

const http = require('http');

const BASE = 'http://localhost:5000/api';
let adminToken = '';
let staffToken = '';
let staffId = '';
let shiftId = '';
let leaveId = '';
let passed = 0;
let failed = 0;
const results = [];

// Dynamic far-future year so re-runs never overlap previous leave records
const _testYear = 2050 + (Math.floor(Date.now() / 1000) % 9000);

function req(method, path, body, token) {
    return new Promise((resolve, reject) => {
        const url = new URL(BASE + path);
        const options = {
            hostname: url.hostname,
            port: url.port,
            path: url.pathname + url.search,
            method,
            headers: { 'Content-Type': 'application/json' },
        };
        if (token) options.headers['Authorization'] = `Bearer ${token}`;
        const r = http.request(options, (res) => {
            let data = '';
            res.on('data', (c) => (data += c));
            res.on('end', () => {
                try {
                    resolve({ status: res.statusCode, body: JSON.parse(data) });
                } catch {
                    resolve({ status: res.statusCode, body: data });
                }
            });
        });
        r.on('error', reject);
        if (body) r.write(JSON.stringify(body));
        r.end();
    });
}

function test(name, pass, detail) {
    if (pass) {
        passed++;
        results.push(`  ✅ ${name}`);
    } else {
        failed++;
        results.push(`  ❌ ${name} — ${detail || 'FAILED'}`);
    }
}

async function run() {
    console.log('\n🔍 CareShift API Test Suite\n' + '='.repeat(50));

    // ════════════════════════════════════════════════════════════
    // 1. AUTH TESTS
    // ════════════════════════════════════════════════════════════
    console.log('\n📋 AUTH TESTS');

    // 1a. Login as admin
    let r = await req('POST', '/auth/login', { email: 'admin@careshift.co.uk', password: 'Admin@123' });
    test('Admin login', r.status === 200 && r.body.token, `status=${r.status}`);
    adminToken = r.body.token || '';

    // 1b. Login as staff
    r = await req('POST', '/auth/login', { email: 'staff@careshift.co.uk', password: 'Staff@123' });
    test('Staff login', r.status === 200 && r.body.token, `status=${r.status}`);
    staffToken = r.body.token || '';
    staffId = r.body._id || '';

    // 1c. Login with wrong password
    r = await req('POST', '/auth/login', { email: 'admin@careshift.co.uk', password: 'wrong' });
    test('Wrong password rejected', r.status === 401, `status=${r.status}`);

    // 1d. Login with non-existent email
    r = await req('POST', '/auth/login', { email: 'nobody@test.com', password: 'Test@123' });
    test('Unknown email rejected', r.status === 401, `status=${r.status}`);

    // 1e. GET /auth/me with token
    r = await req('GET', '/auth/me', null, adminToken);
    test('GET /auth/me works', r.status === 200 && r.body.name, `status=${r.status}`);

    // 1f. Password NOT in response
    test('Password not exposed', !r.body.password, `password field present!`);

    // ════════════════════════════════════════════════════════════
    // 2. SECURITY TESTS
    // ════════════════════════════════════════════════════════════
    console.log('\n🔒 SECURITY TESTS');

    // 2a. No token → blocked
    r = await req('GET', '/shifts', null);
    test('No token → 401', r.status === 401, `status=${r.status}`);

    // 2b. Invalid token → blocked
    r = await req('GET', '/shifts', null, 'invalidtoken123');
    test('Invalid token → 401', r.status === 401, `status=${r.status}`);

    // 2c. Staff can't create shift (admin-only)
    r = await req('POST', '/shifts', { staffId, date: '2026-03-10', startTime: '09:00', endTime: '17:00' }, staffToken);
    test('Staff cannot create shift', r.status === 403, `status=${r.status}`);

    // 2d. Staff can't access admin users list
    r = await req('GET', '/users', null, staffToken);
    test('Staff cannot list users', r.status === 403, `status=${r.status}`);

    // 2e. Staff can't approve leave
    r = await req('PUT', '/leave/000000000000000000000000/approve', null, staffToken);
    test('Staff cannot approve leave', r.status === 403, `status=${r.status}`);

    // ════════════════════════════════════════════════════════════
    // 3. SHIFTS API
    // ════════════════════════════════════════════════════════════
    console.log('\n📅 SHIFTS TESTS');

    // 3a. Admin lists shifts
    r = await req('GET', '/shifts', null, adminToken);
    test('Admin list shifts', r.status === 200 && Array.isArray(r.body), `status=${r.status}`);
    if (r.body.length > 0) shiftId = r.body[0]._id;

    // 3b. Admin creates shift
    r = await req('POST', '/shifts', { staffId: staffId, date: '2026-03-15', startTime: '08:00', endTime: '16:00' }, adminToken);
    test('Admin create shift', r.status === 201 || r.status === 200, `status=${r.status} body=${JSON.stringify(r.body).substring(0, 100)}`);
    if (r.body._id) shiftId = r.body._id;

    // 3c. Staff sees own shifts
    r = await req('GET', '/shifts', null, staffToken);
    test('Staff sees shifts', r.status === 200 && Array.isArray(r.body), `status=${r.status}`);

    // 3d. Get shift by ID
    if (shiftId) {
        r = await req('GET', `/shifts/${shiftId}`, null, adminToken);
        test('Get shift by ID', r.status === 200 && r.body._id, `status=${r.status}`);
    }

    // ════════════════════════════════════════════════════════════
    // 4. ATTENDANCE API
    // ════════════════════════════════════════════════════════════
    console.log('\n⏰ ATTENDANCE TESTS');

    // 4a. Clock in (staff)
    r = await req('POST', '/attendance/clock-in', { shiftId }, staffToken);
    const clockedIn = r.status === 201;
    test('Staff clock in', clockedIn || r.status === 409, `status=${r.status} msg=${r.body?.message}`);

    // 4b. Duplicate clock-in blocked
    if (clockedIn) {
        r = await req('POST', '/attendance/clock-in', { shiftId }, staffToken);
        test('Duplicate clock-in blocked', r.status === 409, `status=${r.status}`);
    }

    // 4c. Clock out
    r = await req('POST', '/attendance/clock-out', { shiftId }, staffToken);
    test('Staff clock out', r.status === 200 || r.status === 404, `status=${r.status} msg=${r.body?.message}`);

    // 4d. Admin lists attendance
    r = await req('GET', '/attendance', null, adminToken);
    test('Admin list attendance', r.status === 200 && Array.isArray(r.body), `status=${r.status}`);

    // ════════════════════════════════════════════════════════════
    // 5. LEAVE API
    // ════════════════════════════════════════════════════════════
    console.log('\n🏖️  LEAVE TESTS');

    // Reset staff annual leave balance so tests are idempotent across re-runs
    await req('PUT', `/users/${staffId}`, { annualLeaveBalance: 224 }, adminToken);

    // 5a. Staff requests annual leave
    r = await req('POST', '/leave', {
        leaveType: 'annual',
        startDate: `${_testYear}-06-01`,
        endDate: `${_testYear}-06-05`,
        reason: 'Summer holiday',
    }, staffToken);
    test('Staff request leave', r.status === 201, `status=${r.status} msg=${r.body?.message}`);
    leaveId = r.body?._id || '';

    // 5b. Staff lists own leave
    r = await req('GET', '/leave', null, staffToken);
    test('Staff list leave', r.status === 200 && Array.isArray(r.body), `status=${r.status}`);

    // 5c. Admin lists all leave
    r = await req('GET', '/leave', null, adminToken);
    test('Admin list all leave', r.status === 200 && Array.isArray(r.body), `status=${r.status}`);

    // 5d. Get leave balance
    r = await req('GET', `/leave/balance/${staffId}`, null, staffToken);
    test('Get leave balance', r.status === 200 && r.body.annualEntitlement === 224, `status=${r.status}`);

    // 5e. Admin approves leave
    if (leaveId) {
        r = await req('PUT', `/leave/${leaveId}/approve`, null, adminToken);
        test('Admin approve leave', r.status === 200 && r.body.status === 'approved', `status=${r.status} msg=${r.body?.message}`);
    } else {
        test('Admin approve leave', false, 'skipped — leave not created');
    }

    // 5f. Check balance deducted
    r = await req('GET', `/leave/balance/${staffId}`, null, staffToken);
    test('Balance deducted after approval', r.status === 200 && r.body.annualLeaveBalance < 224, `balance=${r.body?.annualLeaveBalance}`);

    // 5g. Request another leave, admin rejects
    r = await req('POST', '/leave', {
        leaveType: 'annual',
        startDate: `${_testYear}-07-01`,
        endDate: `${_testYear}-07-02`,
        reason: 'Doctor appointment',
    }, staffToken);
    const rejectLeaveId = r.body?._id;

    if (rejectLeaveId) {
        r = await req('PUT', `/leave/${rejectLeaveId}/reject`, { reason: 'Short staffed' }, adminToken);
        test('Admin reject leave', r.status === 200 && r.body.status === 'rejected', `status=${r.status}`);
    } else {
        test('Admin reject leave', false, 'skipped — leave not created');
    }

    // 5h. Staff cancels own pending leave
    r = await req('POST', '/leave', {
        leaveType: 'sick',
        startDate: `${_testYear}-08-10`,
        endDate: `${_testYear}-08-10`,
    }, staffToken);
    const cancelId = r.body?._id;

    if (cancelId) {
        r = await req('PUT', `/leave/${cancelId}/cancel`, null, staffToken);
        test('Staff cancel leave', r.status === 200 && r.body.status === 'cancelled', `status=${r.status}`);
    }

    // 5i. Insufficient balance check
    r = await req('POST', '/leave', {
        leaveType: 'annual',
        startDate: `${_testYear + 1}-01-01`,
        endDate: `${_testYear + 1}-12-31`,
    }, staffToken);
    test('Insufficient balance blocked', r.status === 400 || r.status === 409, `status=${r.status} msg=${r.body?.message}`);

    // ════════════════════════════════════════════════════════════
    // 6. USERS API
    // ════════════════════════════════════════════════════════════
    console.log('\n👥 USERS TESTS');

    // 6a. Admin lists users
    r = await req('GET', '/users', null, adminToken);
    test('Admin list users', r.status === 200 && Array.isArray(r.body) && r.body.length >= 10, `status=${r.status} count=${r.body?.length}`);

    // 6b. Admin updates user
    const targetUser = r.body?.find(u => u.email === 'sophie@careshift.co.uk');
    if (targetUser) {
        r = await req('PUT', `/users/${targetUser._id}`, { department: 'Emergency', hourlyRate: 18.50 }, adminToken);
        test('Admin update user', r.status === 200 && r.body.department === 'Emergency', `status=${r.status}`);
    }

    // ════════════════════════════════════════════════════════════
    // SUMMARY
    // ════════════════════════════════════════════════════════════
    console.log('\n' + '='.repeat(50));
    results.forEach(r => console.log(r));
    console.log('='.repeat(50));
    console.log(`\n🏁 RESULTS: ${passed} passed, ${failed} failed, ${passed + failed} total\n`);

    process.exit(failed > 0 ? 1 : 0);
}

run().catch(e => { console.error('Test runner error:', e); process.exit(1); });
