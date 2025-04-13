const { CognitoIdentityProviderClient, InitiateAuthCommand } = require('@aws-sdk/client-cognito-identity-provider');
const { SSMClient, GetParameterCommand } = require('@aws-sdk/client-ssm');

const cognitoClient = new CognitoIdentityProviderClient();
const ssmClient = new SSMClient();

exports.handler = async (event) => {
    try {
        const body = JSON.parse(event.body);

        const parameterResponse = await ssmClient.send(new GetParameterCommand({
            Name: '/CLOUD_OPS_MANAGER_COGNITO/CLIENT_ID',
            WithDecryption: true
        }));

        const clientId = parameterResponse.Parameter?.Value;

        const command = new InitiateAuthCommand({
            AuthFlow: 'USER_PASSWORD_AUTH',
            ClientId: clientId,
            AuthParameters: {
                USERNAME: body.username,
                PASSWORD: body.password
            }
        });

        const authResponse = await cognitoClient.send(command);

        return {
            statusCode: 200,
            body: JSON.stringify({
                accessToken: authResponse.AuthenticationResult.AccessToken,
                idToken: authResponse.AuthenticationResult.IdToken,
                refreshToken: authResponse.AuthenticationResult.RefreshToken
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