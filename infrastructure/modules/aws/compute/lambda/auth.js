const AWS = require('aws-sdk');
const cognito = new AWS.CognitoIdentityServiceProvider();

exports.handler = async (event) => {
    try {
        const body = JSON.parse(event.body);

        const params = {
            AuthFlow: 'USER_PASSWORD_AUTH',
            ClientId: await new AWS.SSM().getParameter({ Name: '/CLOUD_OPS_MANAGER_COGNITO/CLIENT_ID' }).promise().then(data => data.Parameter.Value),
            AuthParameters: {
                USERNAME: body.username,
                PASSWORD: body.password
            }
        };

        const response = await cognito.initiateAuth(params).promise();

        return {
            statusCode: 200,
            body: JSON.stringify({
                accessToken: response.AuthenticationResult.AccessToken,
                idToken: response.AuthenticationResult.IdToken,
                refreshToken: response.AuthenticationResult.RefreshToken
            }),
            headers: {
                'Content-Type': 'application/json',
            }
        };
    } catch (error) {
        return {
            statusCode: 401,
            body: JSON.stringify({
                message: 'Authentication failed',
            }),
            headers: {
                'Content-Type': 'application/json',
            }
        };
    }
};