using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;
using Microsoft.Extensions.Logging;
using Scaffolder.Domain.Errors;
using Scaffolder.Domain.Model;
using Scaffolder.Domain.Ports;
using Scaffolder.Infrastructure.Configuration;

namespace Scaffolder.Infrastructure.Persistence;

/// <summary>
/// The repository inventory in the single <c>scaffolder</c> table, keyed
/// <c>REPO#&lt;owner&gt;/&lt;name&gt;</c> / <c>META</c>. Same conditional-write
/// idiom as <see cref="DynamoDbNameReservationStore"/>, for the same reason:
/// at-least-once delivery means this runs twice for one request, and the
/// duplicate has to be a no-op rather than a second repository.
/// </summary>
public sealed class DynamoDbRepositoryRecordStore(
    IAmazonDynamoDB dynamoDb,
    ScaffolderOptions options,
    ILogger<DynamoDbRepositoryRecordStore> logger) : IRepositoryRecordStore
{
    internal const string SortKeyValue = "META";

    public async Task<RepositoryClaimOutcome> ClaimAsync(
        RepositoryRecord record,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(record);

        var request = new PutItemRequest
        {
            TableName = options.TableName,
            Item = ToItem(record),

            // Free slot, or already claimed by this same request. Note this does
            // not overwrite a record that has already reached Created: the item
            // it writes is a fresh claim, and SaveCreatedAsync puts the finished
            // one back. A redelivery therefore rewinds its own record rather than
            // clobbering someone else's.
            ConditionExpression = "attribute_not_exists(PK) OR RequestId = :requestId",
            ExpressionAttributeValues = new Dictionary<string, AttributeValue>
            {
                [":requestId"] = new() { S = record.RequestId },
            },

            ReturnValues = ReturnValue.ALL_OLD,
            ReturnValuesOnConditionCheckFailure = ReturnValuesOnConditionCheckFailure.ALL_OLD,
        };

        try
        {
            var response = await dynamoDb.PutItemAsync(request, cancellationToken);
            var replayed = response.Attributes is { Count: > 0 };

            return replayed ? RepositoryClaimOutcome.AlreadyHeldByThisRequest : RepositoryClaimOutcome.Created;
        }
        catch (ConditionalCheckFailedException ex)
        {
            logger.LogWarning(
                "Repository {FullName} is claimed by another request; {RequestId} was rejected",
                record.FullName,
                record.RequestId);

            throw new RepositoryAlreadyExistsException(record.Owner, record.Name.Value)
            {
                Data = { ["dynamodb"] = ex.Message },
            };
        }
    }

    public async Task SaveCreatedAsync(RepositoryRecord record, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(record);

        if (record.Hosted is null)
        {
            throw new ArgumentException(
                "cannot save a repository record as created without the host's response",
                nameof(record));
        }

        var request = new PutItemRequest
        {
            TableName = options.TableName,
            Item = ToItem(record),

            // Still ours. A task that lost the race for this slot must not be
            // able to stamp its own result over the winner's.
            ConditionExpression = "RequestId = :requestId",
            ExpressionAttributeValues = new Dictionary<string, AttributeValue>
            {
                [":requestId"] = new() { S = record.RequestId },
            },
        };

        try
        {
            await dynamoDb.PutItemAsync(request, cancellationToken);
        }
        catch (ConditionalCheckFailedException ex)
        {
            throw new RepositoryAlreadyExistsException(record.Owner, record.Name.Value)
            {
                Data = { ["dynamodb"] = ex.Message },
            };
        }
    }

    private static Dictionary<string, AttributeValue> ToItem(RepositoryRecord record)
    {
        var item = new Dictionary<string, AttributeValue>
        {
            ["PK"] = new AttributeValue { S = $"REPO#{record.FullName}" },
            ["SK"] = new AttributeValue { S = SortKeyValue },
            ["Owner"] = new AttributeValue { S = record.Owner },
            ["RepositoryName"] = new AttributeValue { S = record.Name.Value },
            ["FullName"] = new AttributeValue { S = record.FullName },
            ["RequestId"] = new AttributeValue { S = record.RequestId },
            ["Template"] = new AttributeValue { S = record.Template },
            ["Status"] = new AttributeValue { S = record.Status.ToString() },
            ["CreatedAt"] = new AttributeValue { S = record.CreatedAt.ToString("O") },

            // The GSI1 partition the drift query will use: "which repositories
            // came from this template?". The index itself is not created yet, but
            // writing the attribute now means the backfill is just creating it.
            ["GSI1PK"] = new AttributeValue { S = $"TEMPLATE#{record.Template}" },
            ["GSI1SK"] = new AttributeValue { S = $"REPO#{record.FullName}" },
        };

        if (record.Hosted is { } hosted)
        {
            item["HostId"] = new AttributeValue { N = hosted.Id.ToString() };
            item["HtmlUrl"] = new AttributeValue { S = hosted.HtmlUrl };
            item["CloneUrl"] = new AttributeValue { S = hosted.CloneUrl };
            item["DefaultBranch"] = new AttributeValue { S = hosted.DefaultBranch };
        }

        // Deliberately no ExpiresAt: the table's TTL is for name reservations,
        // which are meant to lapse. A repository record is the inventory — it
        // outlives the request that created it.
        return item;
    }
}
