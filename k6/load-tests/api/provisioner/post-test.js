import http from 'k6/http';
import check from 'k6';

export let options = {
    vus: 110,
    duration: '1s',
};

export default function () {
    const url = 'your_api_endpoint_here';

    const payload = JSON.stringify({
        "id": "resource-123",
        "resource_type": "ec2",
        "specification": "t2.micro"
    });

    const params = {
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': 'your_api_key_here',
        },
    };

    let res = http.post(url, payload, params);

    check(res, {
        'status is 202': (r) => r.status === 202,
        'status is 429': (r) => r.status === 429,
        'response time is less than 200ms': (r) => r.timings.duration < 200,
    });
}