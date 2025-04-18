CREATE TABLE resources (
    id UUID PRIMARY KEY,
    type TEXT NOT NULL,
    status TEXT NOT NULL,
    provider TEXT NOT NULL,
    metadata JSONB
);

CREATE TABLE aws_ec2_instances (
    id UUID PRIMARY KEY,
    resource_id UUID REFERENCES resources(id),
    instance_type TEXT NOT NULL,
    ami_id TEXT NOT NULL
);