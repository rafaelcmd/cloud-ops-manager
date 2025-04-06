import http from 'k6/http';
import check from 'k6';

export let options = {
    vus: 110,
    duration: '1s',
};

export default function () {
    const url = 'https://dhcuur0kf0.execute-api.us-east-1.amazonaws.com/dev/resource-provisioner';

    const payload = JSON.stringify({
        "id": "resource-123",
        "resource_type": "ec2",
        "specification": "t2.micro"
    });

    const params = {
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': 'N1ygeXVmta9YTkt2H3kYY9fONU9TSWEP2eWWecDR'
        },
    };

    let res = http.post(url, payload, params);

    check(res, {
        'status is 202': (r) => r.status === 202,
        'status is 429': (r) => r.status === 429,
        'response time is less than 200ms': (r) => r.timings.duration < 200,
    });
}