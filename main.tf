variable "region" {}
variable "account" {}

output "primary" {
    value = "${lookup(var.primary_azs, format(\"%s-%s\", var.region, var.account))}"
}
output "secondary" {
    value = "${lookup(var.secondary_azs, format(\"%s-%s\", var.region, var.account))}"
}
output "tertiary" {
    value = "${lookup(var.tertiary_azs, format(\"%s-%s\", var.region, var.account))}"
}

