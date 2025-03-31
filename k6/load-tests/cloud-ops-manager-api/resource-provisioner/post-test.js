import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    vus: 100,           // 100 virtual users
    duration: '1m',     // Run for 1 minute
};

export default function () {
    const url = 'http://cloud-ops-manager-api:5000/resource-provisioner';

    const payload = JSON.stringify({
        "id": "resource-123",
        "resource_type": "ec2",
        "specification": "t2.micro"
    });

    const params = {
        headers: {
            'Content-Type': 'application/json',
        },
    };

    let res = http.post(url, payload, params);

    check(res, {
        'status is 202': (r) => r.status === 202,
        'response time is less than 200ms': (r) => r.timings.duration < 200,
    });

    sleep(1);
}