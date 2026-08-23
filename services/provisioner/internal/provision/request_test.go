package provision

import (
	"slices"
	"testing"
)

const validMessage = `{
  "request_id": "11111111-1111-1111-1111-111111111111",
  "application": {
    "name": "payments-api",
    "template": "dotnet-consumer",
    "owner": "team-payments",
    "description": "Payments processing service"
  },
  "resources": [
    {"name": "payments", "resource_type": "DynamoDB", "cloud_provider": "AWS",
     "specification": {"billing_mode": "PAY_PER_REQUEST"}},
    {"name": "payments-events", "resource_type": "SQS", "cloud_provider": "AWS"}
  ],
  "requested_by": "rafael"
}`

func TestParse_ReadsTheWholeRequest(t *testing.T) {
	request := mustParse(t, validMessage)

	equal(t, "request id", "11111111-1111-1111-1111-111111111111", request.RequestID)
	equal(t, "application name", "payments-api", request.Application.Name)
	equal(t, "template", "dotnet-consumer", request.Application.Template)
	equal(t, "resource count", 2, len(request.Resources))
	equal(t, "specification entry", "PAY_PER_REQUEST", request.Resources[0].Specification["billing_mode"])
}

func TestParse_RejectsAMessageTheSplitCannotUse(t *testing.T) {
	cases := map[string]string{
		"not json":         `{`,
		"no request id":    `{"application":{"name":"payments-api","template":"dotnet-consumer"}}`,
		"no name":          `{"request_id":"r1","application":{"template":"dotnet-consumer"}}`,
		"no template":      `{"request_id":"r1","application":{"name":"payments-api"}}`,
		"blank name":       `{"request_id":"r1","application":{"name":"   ","template":"t"}}`,
		"empty object":     `{}`,
		"old resource DTO": `{"id":"123","resource_type":"VM","cloud_provider":"AWS","specification":"t2.micro"}`,
	}

	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := Parse([]byte(body)); err == nil {
				t.Fatal("a request the split cannot use must not parse")
			}
		})
	}
}

func TestSplit_SendsTheApplicationToTheScaffolderAndTheResourcesToInfra(t *testing.T) {
	scaffold, infra := mustParse(t, validMessage).Split()

	equal(t, "application name", "payments-api", scaffold.ApplicationName)
	equal(t, "template", "dotnet-consumer", scaffold.Template)
	equal(t, "owner", "team-payments", scaffold.Owner)
	equal(t, "description", "Payments processing service", scaffold.Description)

	equal(t, "resource count", 2, len(infra.Resources))

	if types := infra.ResourceTypes(); !slices.Equal(types, []string{"DynamoDB", "SQS"}) {
		t.Fatalf("resource types: want [DynamoDB SQS], got %v", types)
	}
}

func TestSplit_CarriesTheCorrelationIdIntoBothHalves(t *testing.T) {
	// Both halves belong to the same state machine execution, and the scaffolder
	// keys its conditional writes on this value. Omitting it from either half
	// breaks idempotency on that side, with no symptom until a retry occurs.
	request := mustParse(t, validMessage)
	scaffold, infra := request.Split()

	equal(t, "scaffold request id", request.RequestID, scaffold.RequestID)
	equal(t, "infra request id", request.RequestID, infra.RequestID)
}

func TestSplit_CarriesTheApplicationNameIntoTheInfraHalf(t *testing.T) {
	// No individual resource references the application, but the worker names and
	// tags the resources after it, and the outputs are written back to that
	// application's repository.
	_, infra := mustParse(t, validMessage).Split()

	equal(t, "infra application name", "payments-api", infra.ApplicationName)
}

func TestSplit_AnApplicationWithNoResourcesHasNoInfraWork(t *testing.T) {
	scaffold, infra := mustParse(t,
		`{"request_id":"r1","application":{"name":"payments-api","template":"dotnet-consumer"}}`).Split()

	equal(t, "application name", "payments-api", scaffold.ApplicationName)

	if infra.HasWork() {
		t.Fatal("the state machine should skip the infra branch entirely")
	}
}

func mustParse(t *testing.T, body string) Request {
	t.Helper()

	request, err := Parse([]byte(body))
	if err != nil {
		t.Fatalf("parsing a valid request: %v", err)
	}
	return request
}

func equal[T comparable](t *testing.T, what string, want, got T) {
	t.Helper()

	if want != got {
		t.Errorf("%s: want %v, got %v", what, want, got)
	}
}
