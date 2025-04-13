import { CognitoIdentityProviderClient, InitiateAuthCommand } from '@aws-sdk/client-cognito-identity-provider';
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

const cognitoClient = new CognitoIdentityProviderClient();
const ssmClient = new SSMClient();

export const handler = async (event) => {
    try {
        const body = JSON.parse(event.body);

        const parameterResponse = await ssmClient.send(new GetParameterCommand({
            Name: '/cognito/userPoolId',
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