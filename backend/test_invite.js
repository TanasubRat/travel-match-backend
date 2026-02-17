const http = require('http');

const PORT = 3001;

function request(path, method = 'GET', body = null, token = null) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'localhost',
            port: PORT,
            path: '/api' + path,
            method: method,
            headers: {
                'Content-Type': 'application/json',
            }
        };

        if (token) {
            options.headers['Authorization'] = `Bearer ${token}`;
        }

        if (body) {
            const data = JSON.stringify(body);
            options.headers['Content-Length'] = Buffer.byteLength(data);
        }

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const json = data ? JSON.parse(data) : {};
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        resolve(json);
                    } else {
                        console.error(`Error ${res.statusCode} on ${path}:`, json);
                        reject(new Error(`HTTP ${res.statusCode}: ${JSON.stringify(json)}`));
                    }
                } catch (e) {
                    console.error("Raw response:", data);
                    reject(e);
                }
            });
        });

        req.on('error', (e) => reject(e));

        if (body) {
            req.write(JSON.stringify(body));
        }
        req.end();
    });
}

async function run() {
    try {
        const timestamp = Date.now();

        // 1. Register User A (Host)
        const emailA = `host_${timestamp}@test.com`;
        console.log('Registering Host:', emailA);
        const resA = await request('/auth/register', 'POST', {
            email: emailA,
            password: 'password123',
            displayName: 'Host User'
        });
        const tokenA = resA.token;

        // 2. Register User B (Friend)
        const emailB = `friend_${timestamp}@test.com`;
        console.log('Registering Friend:', emailB);
        const resB = await request('/auth/register', 'POST', {
            email: emailB,
            password: 'password123',
            displayName: 'Friend User'
        });
        const tokenB = resB.token;
        const idB = resB.user.id;

        // 3. Host creates a group
        console.log('Host creating group...');
        const resGroup = await request('/groups', 'POST', {
            name: 'Test Trip',
            city: 'Bangkok'
        }, tokenA);
        const groupId = resGroup._id;
        console.log('Group created:', groupId);

        // 4. Host invites Friend
        console.log('Host inviting Friend...');
        const resInvite = await request('/groups/invite', 'POST', {
            email: emailB
        }, tokenA);
        console.log('Invite response:', resInvite);

        // 5. Verify Friend is in group
        console.log('Verifying Friend status...');

        // Check Group details
        const resGroupDetail = await request(`/groups/${groupId}`, 'GET', null, tokenA);
        const members = resGroupDetail.members;
        const isMember = members.some(m => (m.user._id || m.user) === idB);
        console.log('Friend is in group members list:', isMember);

        // Check Friend's profile
        const resFriendProfile = await request('/auth/me', 'GET', null, tokenB);
        const friendGroupId = resFriendProfile.user ? resFriendProfile.user.groupId : resFriendProfile.groupId;

        console.log('Friend groupId in profile:', friendGroupId);

        if (isMember && friendGroupId === groupId) {
            console.log('SUCCESS: Friend successfully invited and added to group!');
        } else {
            console.error('FAILURE: Friend not correctly added.');
            console.log('Expected Group ID:', groupId);
            console.log('Actual Group ID:', friendGroupId);
            process.exit(1);
        }

    } catch (error) {
        console.error('Test Failed:', error.message);
        process.exit(1);
    }
}

run();
