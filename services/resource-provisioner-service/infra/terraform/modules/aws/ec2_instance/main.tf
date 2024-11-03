resource "aws_instance" "ec2_instance" {
    ami           = var.ami
    instance_type = var.instance_type
    tags = {
        Name = var.instance_name
    }
    subnet_id = aws_subnet.ec2_subnet.id
}

resource "aws_subnet" "ec2_subnet" {
    vpc_id            = data.aws_vpc.default.id
    availability_zone = var.subnet_availability_zone
    cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 4, 2)
}